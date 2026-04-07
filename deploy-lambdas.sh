#!/bin/bash

# IDs de los agentes
SUPERVISOR_AGENT_ID="KT1W7DMYOR"
ASIS_AGENT_ID="UXABHLE263"
TOBE_AGENT_ID="YQQVX1FP3V"
S3_BUCKET="poc-code-analyzer-2026"

echo "🚀 Desplegando Lambdas del PoC Code Analyzer"
echo ""
echo "📋 Configuración:"
echo "   Supervisor Agent: $SUPERVISOR_AGENT_ID"
echo "   AS-IS Agent: $ASIS_AGENT_ID"
echo "   TO-BE Agent: $TOBE_AGENT_ID"
echo "   S3 Bucket: $S3_BUCKET"
echo ""

# Solicitar Alias ID
read -p "Ingresa el Supervisor Agent Alias ID: " SUPERVISOR_ALIAS_ID

if [ -z "$SUPERVISOR_ALIAS_ID" ]; then
    echo "❌ Alias ID requerido"
    exit 1
fi

echo ""
echo "📦 Building SAM application..."
sam build

if [ $? -ne 0 ]; then
    echo "❌ Error en sam build"
    exit 1
fi

echo ""
echo "🚀 Deploying to AWS..."
sam deploy \
  --parameter-overrides \
    SupervisorAgentId=$SUPERVISOR_AGENT_ID \
    SupervisorAgentAliasId=$SUPERVISOR_ALIAS_ID \
    S3BucketName=$S3_BUCKET \
  --region us-east-1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Despliegue completado!"
    echo ""
    echo "📋 Lambdas desplegadas:"
    echo "   • invoke-supervisor-agent"
    echo "   • bedrock-asis-lambda"
    echo "   • bedrock-tobe-lambda"
    echo ""
    echo "🔧 Próximos pasos:"
    echo "   1. Configurar Action Group en code-analyzer-asis → Lambda: bedrock-asis-lambda"
    echo "   2. Configurar Action Group en code-analyzer-tobe → Lambda: bedrock-tobe-lambda"
else
    echo "❌ Error en el despliegue"
    exit 1
fi
