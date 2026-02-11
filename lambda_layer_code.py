import json
import logging
import re
from typing import Any, Dict, Optional
from datetime import datetime


def get_logger(log_level: str = 'INFO') -> logging.Logger:
    logger = logging.getLogger()
    logger.setLevel(getattr(logging, log_level.upper(), logging.INFO))
    
    # Formateador con timestamp
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Handler a stdout
    if not logger.handlers:
        handler = logging.StreamHandler()
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    return logger


def format_response(status_code: int, body: Any, is_json: bool = True) -> Dict:
    if is_json and not isinstance(body, str):
        body = json.dumps(body)
    
    return {
        "statusCode": status_code,
        "body": body,
        "headers": {
            "Content-Type": "application/json",
            "X-Timestamp": datetime.utcnow().isoformat()
        }
    }


def validate_message(message: Dict[str, Any]) -> bool:
    if not isinstance(message, dict):
        return False
    
    # Validaciones básicas
    required_fields = ['detail-type', 'detail'] or ['type', 'detail']
    
    has_type = 'detail-type' in message or 'type' in message
    has_detail = 'detail' in message
    
    if not (has_type and has_detail):
        return False
    
    # Validar que detail sea un diccionario
    if not isinstance(message.get('detail'), dict):
        return False
    
    return True


def publish_to_sns(topic_arn: str, message: Dict[str, Any], **kwargs) -> Dict:
    import boto3
    
    sns_client = boto3.client('sns')
    
    try:
        response = sns_client.publish(
            TopicArn=topic_arn,
            Message=json.dumps(message),
            **kwargs
        )
        return {
            'success': True,
            'message_id': response['MessageId']
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def validate_email(email: str) -> bool:
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None


def validate_phone(phone: str) -> bool:
    pattern = r'^\+?1?\d{9,15}$'
    return re.match(pattern, phone) is not None


def get_secret(secret_name: str, region: str = 'us-east-1') -> Optional[Dict]:
    import boto3
    from botocore.exceptions import ClientError
    
    try:
        client = boto3.client('secretsmanager', region_name=region)
        response = client.get_secret_value(SecretId=secret_name)
        
        if 'SecretString' in response:
            return json.loads(response['SecretString'])
        else:
            return response['SecretBinary']
            
    except ClientError as e:
        logging.error(f"Error obteniendo secreto: {str(e)}")
        return None


def batch_sqs_messages(messages: list, queue_url: str) -> Dict:
    import boto3
    
    sqs_client = boto3.client('sqs')
    
    try:
        entries = [
            {
                'Id': str(i),
                'MessageBody': json.dumps(message)
            }
            for i, message in enumerate(messages)
        ]
        
        response = sqs_client.send_message_batch(
            QueueUrl=queue_url,
            Entries=entries
        )
        
        return {
            'success': True,
            'sent': len(response.get('Successful', [])),
            'failed': len(response.get('Failed', []))
        }
        
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def retry_with_backoff(func, max_retries: int = 3, base_delay: float = 1):
    import time
    
    for attempt in range(max_retries):
        try:
            return func()
        except Exception as e:
            if attempt < max_retries - 1:
                delay = base_delay * (2 ** attempt)
                logging.warning(f"Intento {attempt + 1} falló, reintentando en {delay}s: {str(e)}")
                time.sleep(delay)
            else:
                logging.error(f"Falló después de {max_retries} intentos")
                raise


def parse_sqs_message(record: Dict) -> Dict:
    try:
        body = json.loads(record['body'])
        
        # Si SNS envió el mensaje, unwrap la estructura
        if 'Message' in body:
            message = json.loads(body['Message'])
        else:
            message = body
        
        return {
            'message_id': record['messageId'],
            'receipt_handle': record['receiptHandle'],
            'attributes': record.get('attributes', {}),
            'body': message
        }
        
    except json.JSONDecodeError as e:
        logging.error(f"Error parseando SQS message: {str(e)}")
        return {}


class MessageProcessor:
    def __init__(self, logger: logging.Logger = None):
        self.logger = logger or get_logger()
    
    def process(self, message: Dict) -> Dict:
        """Procesa un mensaje"""
        raise NotImplementedError
    
    def validate(self, message: Dict) -> bool:
        """Valida un mensaje"""
        return validate_message(message)
    
    def publish_result(self, result: Dict, topic_arn: str) -> Dict:
        """Publica resultado a SNS"""
        return publish_to_sns(topic_arn, result)
