#!/bin/bash
set -e

# Configuración de Agentes Bedrock - PoC Code Analyzer
# =====================================================

ACCOUNT_ID="766839612947"
REGION="us-east-1"

# IDs de los agentes
SUPERVISOR_AGENT_ID="KT1W7DMYOR"
ASIS_AGENT_ID="UXABHLE263"
TOBE_AGENT_ID="YQQVX1FP3V"

# ARNs de las Lambdas
ASIS_LAMBDA_ARN="arn:aws:lambda:us-east-1:766839612947:function:bedrock-asis-lambda"
TOBE_LAMBDA_ARN="arn:aws:lambda:us-east-1:766839612947:function:bedrock-tobe-lambda"

echo "Configurando agentes de Bedrock..."
echo ""

# ============================================================================
# PASO 1: Configurar Action Group para Agente AS-IS
# ============================================================================
echo "Paso 1: Configurando Action Group para AS-IS Agent..."

# Dar permisos a Bedrock para invocar la Lambda AS-IS
aws lambda add-permission \
  --function-name bedrock-asis-lambda \
  --statement-id bedrock-agent-invoke-asis \
  --action lambda:InvokeFunction \
  --principal bedrock.amazonaws.com \
  --source-arn "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent/${ASIS_AGENT_ID}" \
  2>/dev/null || echo "  Permiso ya existe para AS-IS Lambda"

# Crear el Action Group para AS-IS
cat > /tmp/asis-action-group.json << 'EOF'
{
  "actionGroupName": "asis-document-action-group",
  "actionGroupExecutor": {
    "lambda": "ASIS_LAMBDA_ARN_PLACEHOLDER"
  },
  "functionSchema": {
    "functions": [
      {
        "name": "generar-documento-asis",
        "description": "Genera el documento AS-IS con el análisis del estado actual del código",
        "parameters": {
          "repo_url": {
            "description": "URL del repositorio analizado",
            "type": "string",
            "required": true
          },
          "stack_actual": {
            "description": "Stack tecnológico actual detectado",
            "type": "string",
            "required": true
          },
          "patron_arquitectura": {
            "description": "Patrón arquitectónico identificado",
            "type": "string",
            "required": true
          },
          "componentes": {
            "description": "Componentes principales del sistema",
            "type": "string",
            "required": true
          },
          "dependencias": {
            "description": "Dependencias externas identificadas",
            "type": "string",
            "required": true
          },
          "infraestructura": {
            "description": "Infraestructura y DevOps actual",
            "type": "string",
            "required": true
          },
          "riesgos": {
            "description": "Riesgos y deuda técnica detectados",
            "type": "string",
            "required": true
          }
        }
      }
    ]
  }
}
EOF

sed -i '' "s|ASIS_LAMBDA_ARN_PLACEHOLDER|${ASIS_LAMBDA_ARN}|g" /tmp/asis-action-group.json

aws bedrock-agent create-agent-action-group \
  --agent-id ${ASIS_AGENT_ID} \
  --agent-version DRAFT \
  --cli-input-json file:///tmp/asis-action-group.json \
  2>/dev/null && echo "  Action Group AS-IS creado" || echo "  Action Group AS-IS ya existe"

# ============================================================================
# PASO 2: Configurar Action Group para Agente TO-BE
# ============================================================================
echo ""
echo "Paso 2: Configurando Action Group para TO-BE Agent..."

# Dar permisos a Bedrock para invocar la Lambda TO-BE
aws lambda add-permission \
  --function-name bedrock-tobe-lambda \
  --statement-id bedrock-agent-invoke-tobe \
  --action lambda:InvokeFunction \
  --principal bedrock.amazonaws.com \
  --source-arn "arn:aws:bedrock:${REGION}:${ACCOUNT_ID}:agent/${TOBE_AGENT_ID}" \
  2>/dev/null || echo "  Permiso ya existe para TO-BE Lambda"

# Crear el Action Group para TO-BE
cat > /tmp/tobe-action-group.json << 'EOF'
{
  "actionGroupName": "tobe-document-action-group",
  "actionGroupExecutor": {
    "lambda": "TOBE_LAMBDA_ARN_PLACEHOLDER"
  },
  "functionSchema": {
    "functions": [
      {
        "name": "generar-documento-tobe",
        "description": "Genera el documento TO-BE con la propuesta de modernización",
        "parameters": {
          "repo_url": {
            "description": "URL del repositorio analizado",
            "type": "string",
            "required": true
          },
          "tecnologias_eol": {
            "description": "Tecnologías sin soporte detectadas",
            "type": "string",
            "required": true
          },
          "stack_objetivo": {
            "description": "Stack tecnológico objetivo propuesto",
            "type": "string",
            "required": true
          },
          "estrategia_migracion": {
            "description": "Estrategia de migración recomendada",
            "type": "string",
            "required": true
          },
          "fases": {
            "description": "Fases de la migración",
            "type": "string",
            "required": true
          },
          "quick_wins": {
            "description": "Mejoras rápidas de bajo esfuerzo",
            "type": "string",
            "required": true
          },
          "riesgos_migracion": {
            "description": "Riesgos del proceso de migración",
            "type": "string",
            "required": true
          }
        }
      }
    ]
  }
}
EOF

sed -i '' "s|TOBE_LAMBDA_ARN_PLACEHOLDER|${TOBE_LAMBDA_ARN}|g" /tmp/tobe-action-group.json

aws bedrock-agent create-agent-action-group \
  --agent-id ${TOBE_AGENT_ID} \
  --agent-version DRAFT \
  --cli-input-json file:///tmp/tobe-action-group.json \
  2>/dev/null && echo "  Action Group TO-BE creado" || echo "  Action Group TO-BE ya existe"

# ============================================================================
# PASO 3: Asociar sub-agentes al Supervisor
# ============================================================================
echo ""
echo "Paso 3: Asociando sub-agentes al Supervisor..."

# Nota: La asociación de sub-agentes se hace desde la consola de Bedrock
# porque requiere configuración de instrucciones específicas para cada sub-agente

echo "  NOTA: Este paso debe hacerse manualmente desde la consola de Bedrock:"
echo "      1. Ve a Bedrock Console → Agents → code-analyzer-supervisor"
echo "      2. En 'Collaborator agents', agrega:"
echo "         - AS-IS Agent (ID: ${ASIS_AGENT_ID})"
echo "         - TO-BE Agent (ID: ${TOBE_AGENT_ID})"

# ============================================================================
# PASO 4: Preparar los agentes (crear alias)
# ============================================================================
echo ""
echo "Paso 4: Preparando agentes y creando alias..."

# Preparar AS-IS Agent
echo "  Preparando AS-IS Agent..."
aws bedrock-agent prepare-agent --agent-id ${ASIS_AGENT_ID} > /dev/null
sleep 10

# Crear alias para AS-IS
ASIS_ALIAS_ID=$(aws bedrock-agent create-agent-alias \
  --agent-id ${ASIS_AGENT_ID} \
  --agent-alias-name "prod" \
  --query 'agentAlias.agentAliasId' \
  --output text 2>/dev/null || echo "EXISTING")

echo "  AS-IS Agent preparado | Alias: ${ASIS_ALIAS_ID}"

# Preparar TO-BE Agent
echo "  Preparando TO-BE Agent..."
aws bedrock-agent prepare-agent --agent-id ${TOBE_AGENT_ID} > /dev/null
sleep 10

# Crear alias para TO-BE
TOBE_ALIAS_ID=$(aws bedrock-agent create-agent-alias \
  --agent-id ${TOBE_AGENT_ID} \
  --agent-alias-name "prod" \
  --query 'agentAlias.agentAliasId' \
  --output text 2>/dev/null || echo "EXISTING")

echo "  TO-BE Agent preparado | Alias: ${TOBE_ALIAS_ID}"

# Preparar Supervisor Agent
echo "  Preparando Supervisor Agent..."
aws bedrock-agent prepare-agent --agent-id ${SUPERVISOR_AGENT_ID} > /dev/null
sleep 10

# Crear alias para Supervisor
SUPERVISOR_ALIAS_ID=$(aws bedrock-agent create-agent-alias \
  --agent-id ${SUPERVISOR_AGENT_ID} \
  --agent-alias-name "prod" \
  --query 'agentAlias.agentAliasId' \
  --output text 2>/dev/null || echo "EXISTING")

echo "  Supervisor Agent preparado | Alias: ${SUPERVISOR_ALIAS_ID}"

echo ""
echo "Configuracion completada!"
echo ""
echo "Informacion de los agentes:"
echo "============================================================="
echo "Supervisor Agent:"
echo "  ID:    ${SUPERVISOR_AGENT_ID}"
echo "  Alias: ${SUPERVISOR_ALIAS_ID}"
echo ""
echo "AS-IS Agent:"
echo "  ID:    ${ASIS_AGENT_ID}"
echo "  Alias: ${ASIS_ALIAS_ID}"
echo ""
echo "TO-BE Agent:"
echo "  ID:    ${TOBE_AGENT_ID}"
echo "  Alias: ${TOBE_ALIAS_ID}"
echo "============================================================="
echo ""
echo "Proximo paso:"
echo "   Actualiza invoke-supervisor-agent.py con:"
echo "   SUPERVISOR_AGENT_ID       = \"${SUPERVISOR_AGENT_ID}\""
echo "   SUPERVISOR_AGENT_ALIAS_ID = \"${SUPERVISOR_ALIAS_ID}\""
echo ""
