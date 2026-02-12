import json
import logging
import os
from datetime import datetime
from typing import Dict, List, Any
import boto3
from botocore.exceptions import ClientError

try:
    from common_utils import (
        get_logger, 
        format_response, 
        validate_message,
        publish_to_sns
    )
except ImportError:
    get_logger = logging.getLogger
    format_response = lambda x, y: {"statusCode": x, "body": y}
    validate_message = lambda x: x
    publish_to_sns = lambda x, y: None

logger = get_logger(os.getenv('LOG_LEVEL', 'INFO'))
sns_client = boto3.client('sns')
sqs_client = boto3.client('sqs')

SNS_TOPIC_ARN = os.getenv('SNS_TOPIC_ARN')
SQS_QUEUE_URL = os.getenv('SQS_QUEUE_URL')
ENVIRONMENT = os.getenv('ENVIRONMENT', 'Dev')


def lambda_handler(event, context):
    """
    Handler principal para procesar mensajes de SQS
    
    Args:
        event: SQS event con múltiples Records
        context: Lambda context object
        
    Returns:
        dict: Resultado con batch item failures si hay
    """
    logger.info(f"Procesando {len(event.get('Records', []))} mensajes")
    logger.debug(f"Event: {json.dumps(event)}")
    
    batch_item_failures = []
    
    for record in event.get('Records', []):
        try:
            message_body = json.loads(record['body'])
            message_id = record['messageId']
            receipt_handle = record['receiptHandle']
            
            logger.info(f"Procesando mensaje: {message_id}")
            logger.debug(f"Contenido: {json.dumps(message_body)}")
            
            if not validate_message(message_body):
                logger.warning(f"Mensaje inválido: {message_id}")
                continue
            
            result = process_message(message_body, message_id)
            
            if result['success']:
                logger.info(f"✓ Mensaje procesado exitosamente: {message_id}")
                # Aquí SQS elimina automáticamente el mensaje si ReportBatchItemFailures
            else:
                logger.error(f"✗ Error procesando mensaje: {result.get('error')}")
                batch_item_failures.append({
                    "itemId": message_id
                })
                
        except json.JSONDecodeError as e:
            logger.error(f"Error decodificando JSON: {str(e)}", exc_info=True)
            batch_item_failures.append({"itemId": record['messageId']})
            
        except Exception as e:
            logger.error(f"Error inesperado: {str(e)}", exc_info=True)
            batch_item_failures.append({"itemId": record['messageId']})
    
    return {
        "batchItemFailures": batch_item_failures,
        "processedCount": len(event.get('Records', [])) - len(batch_item_failures),
        "failureCount": len(batch_item_failures)
    }


def process_message(message: Dict[str, Any], message_id: str) -> Dict[str, Any]:
    """
    Procesa un mensaje individual según su tipo
    
    Args:
        message: Contenido del mensaje
        message_id: ID del mensaje SQS
        
    Returns:
        dict: Resultado del procesamiento
    """
    try:
        event_type = message.get('detail-type', message.get('type', 'unknown'))
        
        logger.info(f"Tipo de evento: {event_type}")
        
        handlers = {
            'Order Placed': handle_order_placed,
            'Payment Processed': handle_payment_processed,
            'Status Update': handle_status_update,
            'custom': handle_custom_event
        }
        
        handler = handlers.get(event_type, handle_custom_event)
        result = handler(message, message_id)
        
        return result
        
    except Exception as e:
        logger.error(f"Error en process_message: {str(e)}", exc_info=True)
        return {
            "success": False,
            "error": str(e),
            "message_id": message_id
        }


def handle_order_placed(message: Dict, message_id: str) -> Dict[str, Any]:
    """Procesa órdenes colocadas"""
    logger.info("Procesando pedido...")
    
    try:
        order_id = message.get('detail', {}).get('order_id', 'unknown')
        customer_id = message.get('detail', {}).get('customer_id')
        amount = message.get('detail', {}).get('amount')
        
        logger.info(f"Pedido {order_id} recibido de cliente {customer_id} por ${amount}")
        
        publish_event({
            'type': 'Order Confirmed',
            'order_id': order_id,
            'timestamp': datetime.utcnow().isoformat(),
            'source': 'message_processor'
        })
        
        return {
            "success": True,
            "order_id": order_id,
            "processed_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error en handle_order_placed: {str(e)}")
        return {"success": False, "error": str(e)}


def handle_payment_processed(message: Dict, message_id: str) -> Dict[str, Any]:
    """Procesa pagos"""
    logger.info("Procesando pago...")
    
    try:
        payment_id = message.get('detail', {}).get('payment_id', 'unknown')
        order_id = message.get('detail', {}).get('order_id')
        status = message.get('detail', {}).get('status')
        
        logger.info(f"Pago {payment_id} para orden {order_id}: {status}")
        
        if status == 'successful':
            publish_event({
                'type': 'Payment Confirmed',
                'payment_id': payment_id,
                'timestamp': datetime.utcnow().isoformat(),
                'source': 'message_processor'
            })
        
        return {
            "success": True,
            "payment_id": payment_id,
            "status": status
        }
        
    except Exception as e:
        logger.error(f"Error en handle_payment_processed: {str(e)}")
        return {"success": False, "error": str(e)}


def handle_status_update(message: Dict, message_id: str) -> Dict[str, Any]:
    """Procesa actualizaciones de estado"""
    logger.info("Procesando actualización de estado...")
    
    try:
        resource_id = message.get('detail', {}).get('resource_id')
        new_status = message.get('detail', {}).get('status')
        
        logger.info(f"Recurso {resource_id} actualizado a: {new_status}")
        
        return {
            "success": True,
            "resource_id": resource_id,
            "new_status": new_status,
            "timestamp": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error en handle_status_update: {str(e)}")
        return {"success": False, "error": str(e)}


def handle_custom_event(message: Dict, message_id: str) -> Dict[str, Any]:
    """Handler genérico para eventos no categorizados"""
    logger.info("Procesando evento personalizado...")
    
    try:
        event_type = message.get('type', message.get('detail-type', 'unknown'))
        logger.info(f"Evento tipo: {event_type}")
        logger.debug(f"Datos: {json.dumps(message)}")
        
        return {
            "success": True,
            "event_type": event_type,
            "message_id": message_id,
            "processed_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error en handle_custom_event: {str(e)}")
        return {"success": False, "error": str(e)}


def publish_event(event_data: Dict[str, Any]) -> None:
    try:
        message = json.dumps(event_data)
        
        response = sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=event_data.get('type', 'Event'),
            Message=message,
            MessageAttributes={
                'EventType': {
                    'StringValue': event_data.get('type', 'custom'),
                    'DataType': 'String'
                },
                'Source': {
                    'StringValue': 'lambda-processor',
                    'DataType': 'String'
                },
                'Environment': {
                    'StringValue': ENVIRONMENT,
                    'DataType': 'String'
                }
            }
        )
        
        logger.info(f"Evento publicado a SNS: {response['MessageId']}")
        
    except ClientError as e:
        logger.error(f"Error publicando a SNS: {str(e)}")
        raise
    except Exception as e:
        logger.error(f"Error inesperado en publish_event: {str(e)}")
        raise
