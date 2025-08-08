
import boto3
import os
import json
import logging
from botocore.exceptions import ClientError, BotoCoreError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    ecs_client = boto3.client('ecs')

    cluster = os.environ.get("ECS_CLUSTER")
    services_json = os.environ.get("ECS_SERVICES")

    if not cluster or not services_json:
        logger.error("ECS_CLUSTER or ECS_SERVICES environment variable is missing.")
        return {
            "statusCode": 500,
            "body": "Missing ECS_CLUSTER or ECS_SERVICES"
        }

    try:
        services = json.loads(services_json)
        if not isinstance(services, list):
            raise ValueError("ECS_SERVICES must be a JSON list")

        results = []
        for service in services:
            logger.info(f"Restarting ECS service: {service} in cluster: {cluster}")
            response = ecs_client.update_service(
                cluster=cluster,
                service=service,
                forceNewDeployment=True
            )
            results.append(f"Service '{service}' restarted.")

        return {
            "statusCode": 200,
            "body": f"Restarted services: {', '.join(services)}"
        }

    except ClientError as e:
        logger.error(f"AWS ClientError: {e.response['Error']['Message']}", exc_info=True)
        return {
            "statusCode": 500,
            "body": f"ClientError restarting ECS services: {e.response['Error']['Message']}"
        }

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return {
            "statusCode": 500,
            "body": f"Unexpected error occurred: {str(e)}"
        }
