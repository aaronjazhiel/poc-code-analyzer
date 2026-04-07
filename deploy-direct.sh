#!/bin/bash

echo "🚀 Desplegando Lambdas para PoC Code Analyzer"
echo ""

REGION="us-east-1"
S3_BUCKET="poc-code-analyzer-2026"
SUPERVISOR_AGENT_ID="KT1W7DMYOR"
ASIS_AGENT_ID="UXABHLE263"
TOBE_AGENT_ID="YQQVX1FP3V"

# Crear rol IAM para invoke-supervisor-agent
echo "📋 Creando rol IAM para invoke-supervisor-agent..."
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role \
  --role-name lambda-invoke-supervisor-role \
  --assume-role-policy-document file://trust-policy.json \
  --region $REGION 2>/dev/null || echo "Rol ya existe"

aws iam attach-role-policy \
  --role-name lambda-invoke-supervisor-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > bedrock-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "bedrock:InvokeAgent",
    "Resource": "arn:aws:bedrock:$REGION:*:agent-alias/*/*"
  }]
}
EOF

aws iam put-role-policy \
  --role-name lambda-invoke-supervisor-role \
  --policy-name BedrockInvokePolicy \
  --policy-document file://bedrock-policy.json

# Crear rol IAM para bedrock-asis-lambda y bedrock-tobe-lambda
echo "📋 Creando rol IAM para lambdas de documentos..."
aws iam create-role \
  --role-name lambda-bedrock-docs-role \
  --assume-role-policy-document file://trust-policy.json \
  --region $REGION 2>/dev/null || echo "Rol ya existe"

aws iam attach-role-policy \
  --role-name lambda-bedrock-docs-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

cat > s3-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::$S3_BUCKET/documentos-generados/*"
  }]
}
EOF

aws iam put-role-policy \
  --role-name lambda-bedrock-docs-role \
  --policy-name S3PutObjectPolicy \
  --policy-document file://s3-policy.json

echo "⏳ Esperando 10 segundos para que los roles se propaguen..."
sleep 10

# Obtener ARNs de los roles
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
SUPERVISOR_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/lambda-invoke-supervisor-role"
DOCS_ROLE_ARN="arn:aws:iam::$ACCOUNT_ID:role/lambda-bedrock-docs-role"

# Crear paquetes ZIP
echo "📦 Empaquetando funciones Lambda..."
zip -q invoke-supervisor-agent.zip invoke-supervisor-agent.py
zip -q bedrock-asis-lambda.zip bedrock-asis-lambda.py
zip -q bedrock-tobe-lambda.zip bedrock-tobe-lambda.py

# Desplegar invoke-supervisor-agent
echo "🚀 Desplegando invoke-supervisor-agent..."
aws lambda create-function \
  --function-name invoke-supervisor-agent \
  --runtime python3.12 \
  --role $SUPERVISOR_ROLE_ARN \
  --handler invoke-supervisor-agent.lambda_handler \
  --zip-file fileb://invoke-supervisor-agent.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment "Variables={SUPERVISOR_AGENT_ID=$SUPERVISOR_AGENT_ID,SUPERVISOR_AGENT_ALIAS_ID=PLACEHOLDER}" \
  --region $REGION 2>/dev/null || \
aws lambda update-function-code \
  --function-name invoke-supervisor-agent \
  --zip-file fileb://invoke-supervisor-agent.zip \
  --region $REGION

# Desplegar bedrock-asis-lambda
echo "🚀 Desplegando bedrock-asis-lambda..."
aws lambda create-function \
  --function-name bedrock-asis-lambda \
  --runtime python3.12 \
  --role $DOCS_ROLE_ARN \
  --handler bedrock-asis-lambda.lambda_handler \
  --zip-file fileb://bedrock-asis-lambda.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment "Variables={S3_BUCKET=$S3_BUCKET}" \
  --region $REGION 2>/dev/null || \
aws lambda update-function-code \
  --function-name bedrock-asis-lambda \
  --zip-file fileb://bedrock-asis-lambda.zip \
  --region $REGION

# Desplegar bedrock-tobe-lambda
echo "🚀 Desplegando bedrock-tobe-lambda..."
aws lambda create-function \
  --function-name bedrock-tobe-lambda \
  --runtime python3.12 \
  --role $DOCS_ROLE_ARN \
  --handler bedrock-tobe-lambda.lambda_handler \
  --zip-file fileb://bedrock-tobe-lambda.zip \
  --timeout 300 \
  --memory-size 512 \
  --environment "Variables={S3_BUCKET=$S3_BUCKET}" \
  --region $REGION 2>/dev/null || \
aws lambda update-function-code \
  --function-name bedrock-tobe-lambda \
  --zip-file fileb://bedrock-tobe-lambda.zip \
  --region $REGION

# Limpiar archivos temporales
rm -f trust-policy.json bedrock-policy.json s3-policy.json
rm -f invoke-supervisor-agent.zip bedrock-asis-lambda.zip bedrock-tobe-lambda.zip

echo ""
echo "✅ Lambdas desplegadas exitosamente!"
echo ""
echo "📋 Funciones creadas:"
echo "   • invoke-supervisor-agent"
echo "   • bedrock-asis-lambda"
echo "   • bedrock-tobe-lambda"
echo ""
echo "🔧 Próximos pasos:"
echo "   1. Preparar los 3 agentes en Bedrock Console (botón Prepare)"
echo "   2. Crear alias para code-analyzer-supervisor"
echo "   3. Actualizar variable SUPERVISOR_AGENT_ALIAS_ID en invoke-supervisor-agent"
echo "   4. Configurar Action Groups en los agentes AS-IS y TO-BE"
