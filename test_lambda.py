#!/usr/bin/env python3
"""
Test script for the ECS restart Lambda function
"""
import sys
import os
import json
from unittest.mock import Mock, patch, MagicMock

# Add the lambda directory to the path
sys.path.insert(0, 'modules/terraform-ecs-restart-lambda/lambda')

# Import the lambda function
from restart_ecs import lambda_handler

def test_lambda_handler():
    """Test the lambda handler function"""
    
    # Test case 1: Missing environment variables
    print("Test 1: Missing environment variables")
    with patch('boto3.client') as mock_boto_client:
        with patch.dict(os.environ, {}, clear=True):
            result = lambda_handler({}, {})
            assert result['statusCode'] == 500
            assert 'Missing ECS_CLUSTER or ECS_SERVICES' in result['body']
            print("✓ Correctly handles missing environment variables")
    
    # Test case 2: Invalid JSON in ECS_SERVICES
    print("\nTest 2: Invalid JSON in ECS_SERVICES")
    with patch('boto3.client') as mock_boto_client:
        with patch.dict(os.environ, {'ECS_CLUSTER': 'test-cluster', 'ECS_SERVICES': 'invalid-json'}):
            result = lambda_handler({}, {})
            assert result['statusCode'] == 500
            print("✓ Correctly handles invalid JSON")
    
    # Test case 3: Successful execution
    print("\nTest 3: Successful execution")
    mock_ecs_client = Mock()
    mock_ecs_client.update_service.return_value = {'service': {'serviceName': 'test-service'}}
    
    with patch('boto3.client', return_value=mock_ecs_client):
        with patch.dict(os.environ, {
            'ECS_CLUSTER': 'test-cluster',
            'ECS_SERVICES': '["service1", "service2"]'
        }):
            result = lambda_handler({}, {})
            assert result['statusCode'] == 200
            assert 'service1' in result['body']
            assert 'service2' in result['body']
            
            # Verify ECS client was called correctly
            assert mock_ecs_client.update_service.call_count == 2
            mock_ecs_client.update_service.assert_any_call(
                cluster='test-cluster',
                service='service1',
                forceNewDeployment=True
            )
            mock_ecs_client.update_service.assert_any_call(
                cluster='test-cluster',
                service='service2',
                forceNewDeployment=True
            )
            print("✓ Successfully processes valid input and calls ECS API")
    
    # Test case 4: AWS ClientError
    print("\nTest 4: AWS ClientError handling")
    from botocore.exceptions import ClientError
    
    mock_ecs_client = Mock()
    error_response = {'Error': {'Code': 'ServiceNotFound', 'Message': 'Service not found'}}
    mock_ecs_client.update_service.side_effect = ClientError(error_response, 'UpdateService')
    
    with patch('boto3.client', return_value=mock_ecs_client):
        with patch.dict(os.environ, {
            'ECS_CLUSTER': 'test-cluster',
            'ECS_SERVICES': '["nonexistent-service"]'
        }):
            result = lambda_handler({}, {})
            assert result['statusCode'] == 500
            assert 'Service not found' in result['body']
            print("✓ Correctly handles AWS ClientError")
    
    print("\n🎉 All tests passed!")

if __name__ == '__main__':
    test_lambda_handler()