import json
import logging
import os
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Función Lambda que procesa mensajes de SQS.
    Cada registro en el event es un mensaje SQS.
    """
    
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    project = os.environ.get('PROJECT', 'unknown')
    
    logger.info(f"Starting message processor - Environment: {environment}, Project: {project}")
    logger.info(f"Received {len(event.get('Records', []))} messages")
    
    batchItemFailures = []
    
    for record in event.get('Records', []):
        try:
            message_id = record['messageId']
            body = json.loads(record['body'])
            
            logger.info(f"Processing message {message_id}")
            logger.info(f"Message body: {json.dumps(body)}")
            
            # ============================================
            # AQUÍ VÁ TU LÓGICA DE PROCESAMIENTO
            # ============================================
            # Ejemplo: Procesar evento, guardar en BD, etc.
            
            result = process_message(body)
            
            logger.info(f"Message {message_id} processed successfully: {result}")
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse message {record['messageId']}: {str(e)}")
            batchItemFailures.append({
                "itemId": record['messageId']
            })
        except Exception as e:
            logger.error(f"Error processing message {record['messageId']}: {str(e)}")
            batchItemFailures.append({
                "itemId": record['messageId']
            })
    
    return {
        'batchItemFailures': batchItemFailures,
        'statusCode': 200,
        'timestamp': datetime.utcnow().isoformat()
    }


def process_message(message_body):
    """
    Función auxiliar para procesar cada mensaje.
    
    Parámetros:
        message_body (dict): Contenido del mensaje SNS/SQS
    
    Retorna:
        dict: Resultado del procesamiento
    """
    
    # Extraer campos del mensaje
    message_type = message_body.get('type')
    payload = message_body.get('payload', {})
    
    logger.info(f"Message type: {message_type}")
    logger.info(f"Payload: {json.dumps(payload)}")
    
    # Implementar lógica según el tipo de mensaje
    if message_type == 'user.created':
        # Procesar nuevo usuario
        user_id = payload.get('user_id')
        email = payload.get('email')
        logger.info(f"Processing new user: {email} (ID: {user_id})")
        # TODO: Guardar en BD, enviar email, etc.
        return {'status': 'user_processed', 'user_id': user_id}
    
    elif message_type == 'order.placed':
        # Procesar nueva orden
        order_id = payload.get('order_id')
        amount = payload.get('amount')
        logger.info(f"Processing order: {order_id} (Amount: ${amount})")
        # TODO: Crear pedido en BD, generar factura, etc.
        return {'status': 'order_processed', 'order_id': order_id}
    
    else:
        logger.warning(f"Unknown message type: {message_type}")
        return {'status': 'unknown_type', 'type': message_type}
