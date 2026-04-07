#!/bin/bash
set -e

ACCOUNT_ID="766839612947"
REGION="us-east-1"

SUPERVISOR_AGENT_ID="KT1W7DMYOR"
SUPERVISOR_AGENT_ALIAS_ID="XVHURY6DYH"

echo "Desplegando Lambda de entrada (invoke-supervisor-agent)..."
echo ""

# Empaquetar Lambda
cd /Users/adelgado/Downloads/poc-code-analyzer
zip -q invoke-supervisor-agent.zip invoke-supervisor-agent.py

# Verificar si la Lambda ya existe
if aws lambda get-function --function-name invoke-supervisor-agent 2>/dev/null; then
    echo "Lambda ya existe, actualizando codigo..."
    aws lambda update-function-code \
      --function-name invoke-supervisor-agent \
      --zip-file fileb://invoke-supervisor-agent.zip > /dev/null
    
    echo "Actualizando variables de entorno..."
    aws lambda update-function-configuration \
      --function-name invoke-supervisor-agent \
      --environment Variables="{SUPERVISOR_AGENT_ID=${SUPERVISOR_AGENT_ID},SUPERVISOR_AGENT_ALIAS_ID=${SUPERVISOR_AGENT_ALIAS_ID}}" > /dev/null
    
    echo "Lambda actualizada exitosamente"
else
    echo "Creando nueva Lambda..."
    aws lambda create-function \
      --function-name invoke-supervisor-agent \
      --runtime python3.11 \
      --role arn:aws:iam::${ACCOUNT_ID}:role/poc-supervisor-lambda-role \
      --handler invoke-supervisor-agent.lambda_handler \
      --zip-file fileb://invoke-supervisor-agent.zip \
      --timeout 300 \
      --environment Variables="{SUPERVISOR_AGENT_ID=${SUPERVISOR_AGENT_ID},SUPERVISOR_AGENT_ALIAS_ID=${SUPERVISOR_AGENT_ALIAS_ID}}" > /dev/null
    
    echo "Lambda creada exitosamente"
fi

echo ""
echo "Resumen de la configuracion:"
echo "============================================================="
echo "Lambda de entrada: invoke-supervisor-agent"
echo "ARN: arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:invoke-supervisor-agent"
echo ""
echo "Supervisor Agent ID: ${SUPERVISOR_AGENT_ID}"
echo "Supervisor Agent Alias ID: ${SUPERVISOR_AGENT_ALIAS_ID}"
echo "============================================================="
echo ""
echo "Probar el PoC:"
echo ""
echo "aws lambda invoke \\"
echo "  --function-name invoke-supervisor-agent \\"
echo "  --payload '{\"body\": \"{\\\"repo_url\\\": \\\"https://github.com/spring-projects/spring-petclinic\\\", \\\"sessionId\\\": \\\"test-001\\\"}\"}' \\"
echo "  --cli-binary-format raw-in-base64-out \\"
echo "  output.json && cat output.json"
echo ""
