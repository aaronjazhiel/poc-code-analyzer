#!/bin/bash

echo "🔍 Obteniendo IDs de los agentes de Bedrock..."
echo ""

# Obtener Agent ID del Supervisor
SUPERVISOR_ID=$(aws bedrock-agent list-agents --region us-east-1 --query "agentSummaries[?agentName=='code-analyzer-supervisor'].agentId" --output text)

if [ -z "$SUPERVISOR_ID" ]; then
    echo "❌ No se encontró el agente code-analyzer-supervisor"
    exit 1
fi

echo "✅ Supervisor Agent ID: $SUPERVISOR_ID"

# Obtener Alias ID del Supervisor
SUPERVISOR_ALIAS_ID=$(aws bedrock-agent list-agent-aliases --agent-id $SUPERVISOR_ID --region us-east-1 --query "agentAliasSummaries[0].agentAliasId" --output text)

if [ -z "$SUPERVISOR_ALIAS_ID" ]; then
    echo "❌ No se encontró alias para el agente supervisor"
    echo "ℹ️  Debes crear un alias en la consola de Bedrock para el agente supervisor"
    exit 1
fi

echo "✅ Supervisor Alias ID: $SUPERVISOR_ALIAS_ID"
echo ""

# Obtener IDs de los otros agentes (para referencia)
ASIS_ID=$(aws bedrock-agent list-agents --region us-east-1 --query "agentSummaries[?agentName=='code-analyzer-asis'].agentId" --output text)
TOBE_ID=$(aws bedrock-agent list-agents --region us-east-1 --query "agentSummaries[?agentName=='code-analyzer-tobe'].agentId" --output text)

echo "📋 Resumen de agentes:"
echo "   Supervisor: $SUPERVISOR_ID"
echo "   AS-IS: $ASIS_ID"
echo "   TO-BE: $TOBE_ID"
echo ""

# Guardar en archivo para usar en deployment
cat > agent-ids.txt <<EOF
SUPERVISOR_AGENT_ID=$SUPERVISOR_ID
SUPERVISOR_AGENT_ALIAS_ID=$SUPERVISOR_ALIAS_ID
ASIS_AGENT_ID=$ASIS_ID
TOBE_AGENT_ID=$TOBE_ID
EOF

echo "✅ IDs guardados en agent-ids.txt"
