#!/bin/bash
set -e

ACCOUNT_ID="766839612947"
REGION="us-east-1"

echo "Creando roles IAM para los agentes de Bedrock..."
echo ""

# Crear rol para agentes de Bedrock
cat > /tmp/bedrock-agent-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "bedrock.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "ACCOUNT_ID_PLACEHOLDER"
        },
        "ArnLike": {
          "aws:SourceArn": "arn:aws:bedrock:REGION_PLACEHOLDER:ACCOUNT_ID_PLACEHOLDER:agent/*"
        }
      }
    }
  ]
}
EOF

sed -i '' "s/ACCOUNT_ID_PLACEHOLDER/${ACCOUNT_ID}/g" /tmp/bedrock-agent-trust-policy.json
sed -i '' "s/REGION_PLACEHOLDER/${REGION}/g" /tmp/bedrock-agent-trust-policy.json

# Crear el rol
aws iam create-role \
  --role-name AmazonBedrockExecutionRoleForAgents_poc \
  --assume-role-policy-document file:///tmp/bedrock-agent-trust-policy.json \
  2>/dev/null && echo "Rol creado exitosamente" || echo "Rol ya existe"

# Adjuntar política para invocar modelos de Bedrock
cat > /tmp/bedrock-agent-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:*::foundation-model/*"
      ]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name AmazonBedrockExecutionRoleForAgents_poc \
  --policy-name BedrockModelInvokePolicy \
  --policy-document file:///tmp/bedrock-agent-policy.json

echo ""
echo "Rol creado: AmazonBedrockExecutionRoleForAgents_poc"
echo "ARN: arn:aws:iam::${ACCOUNT_ID}:role/AmazonBedrockExecutionRoleForAgents_poc"
echo ""
echo "IMPORTANTE: Debes asignar este rol a cada agente desde la consola de Bedrock:"
echo "  1. Ve a Bedrock Console -> Agents"
echo "  2. Para cada agente (Supervisor, AS-IS, TO-BE):"
echo "     - Edita el agente"
echo "     - En 'Agent resource role', selecciona: AmazonBedrockExecutionRoleForAgents_poc"
echo "     - Guarda los cambios"
echo ""
