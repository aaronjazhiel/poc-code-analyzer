#!/bin/bash
set -e

# PoC Code Analyzer - Script de Despliegue Automatizado
# ======================================================

BUCKET_NAME="poc-code-analyzer-docs-766839612947"
REGION="us-east-1"
ACCOUNT_ID="766839612947"

echo "🚀 Iniciando despliegue del PoC Code Analyzer..."
echo ""

# 1. Crear roles IAM para las Lambdas
echo "📋 Paso 1: Creando roles IAM..."

# Rol para Lambda Supervisor
aws iam create-role \
  --role-name poc-supervisor-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "  ✓ Rol poc-supervisor-lambda-role ya existe"

# Rol para Lambda AS-IS
aws iam create-role \
  --role-name poc-asis-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "  ✓ Rol poc-asis-lambda-role ya existe"

# Rol para Lambda TO-BE
aws iam create-role \
  --role-name poc-tobe-lambda-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || echo "  ✓ Rol poc-tobe-lambda-role ya existe"

sleep 5

# 2. Adjuntar políticas a los roles
echo ""
echo "🔐 Paso 2: Configurando permisos..."

# Permisos básicos de Lambda (CloudWatch Logs)
aws iam attach-role-policy \
  --role-name poc-supervisor-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name poc-asis-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name poc-tobe-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Permisos para invocar Bedrock Agent (Supervisor)
aws iam put-role-policy \
  --role-name poc-supervisor-lambda-role \
  --policy-name BedrockAgentInvokePolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["bedrock:InvokeAgent"],
      "Resource": "arn:aws:bedrock:'$REGION':'$ACCOUNT_ID':agent-alias/*/*"
    }]
  }'

# Permisos S3 para AS-IS y TO-BE
aws iam put-role-policy \
  --role-name poc-asis-lambda-role \
  --policy-name S3WritePolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::'$BUCKET_NAME'/documentos-generados/*"
    }]
  }'

aws iam put-role-policy \
  --role-name poc-tobe-lambda-role \
  --policy-name S3WritePolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": ["s3:PutObject"],
      "Resource": "arn:aws:s3:::'$BUCKET_NAME'/documentos-generados/*"
    }]
  }'

sleep 5

# 3. Crear funciones Lambda
echo ""
echo "⚡ Paso 3: Creando funciones Lambda..."

# Empaquetar Lambda AS-IS
cd /Users/adelgado/Downloads/poc-code-analyzer
zip -q bedrock-asis-lambda.zip bedrock-asis-lambda.py

aws lambda create-function \
  --function-name bedrock-asis-lambda \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/poc-asis-lambda-role \
  --handler bedrock-asis-lambda.lambda_handler \
  --zip-file fileb://bedrock-asis-lambda.zip \
  --timeout 60 \
  --environment Variables="{S3_BUCKET=$BUCKET_NAME}" \
  2>/dev/null && echo "  ✓ Lambda bedrock-asis-lambda creada" || echo "  ✓ Lambda bedrock-asis-lambda ya existe"

# Empaquetar Lambda TO-BE
zip -q bedrock-tobe-lambda.zip bedrock-tobe-lambda.py

aws lambda create-function \
  --function-name bedrock-tobe-lambda \
  --runtime python3.11 \
  --role arn:aws:iam::${ACCOUNT_ID}:role/poc-tobe-lambda-role \
  --handler bedrock-tobe-lambda.lambda_handler \
  --zip-file fileb://bedrock-tobe-lambda.zip \
  --timeout 60 \
  --environment Variables="{S3_BUCKET=$BUCKET_NAME}" \
  2>/dev/null && echo "  ✓ Lambda bedrock-tobe-lambda creada" || echo "  ✓ Lambda bedrock-tobe-lambda ya existe"

echo ""
echo "✅ Despliegue completado!"
echo ""
echo "📝 Próximos pasos manuales:"
echo ""
echo "1. Crear los 3 agentes en AWS Bedrock Console:"
echo "   - Supervisor Agent (con MCP GitHub tool)"
echo "   - AS-IS Agent (con Action Group → bedrock-asis-lambda)"
echo "   - TO-BE Agent (con Action Group → bedrock-tobe-lambda)"
echo ""
echo "2. Obtener los IDs del Supervisor Agent y crear la Lambda de entrada:"
echo "   - SUPERVISOR_AGENT_ID"
echo "   - SUPERVISOR_AGENT_ALIAS_ID"
echo ""
echo "3. Bucket S3 creado: s3://$BUCKET_NAME"
echo ""
