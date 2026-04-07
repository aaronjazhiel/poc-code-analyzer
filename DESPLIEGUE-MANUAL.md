# Guía de Despliegue Manual - Lambdas PoC Code Analyzer

## Archivos ZIP listos:
- invoke-supervisor-agent.zip
- bedrock-asis-lambda.zip  
- bedrock-tobe-lambda.zip

---

## Lambda 1: invoke-supervisor-agent

1. Ve a: https://console.aws.amazon.com/lambda/home?region=us-east-1#/create/function
2. **Create function**
3. **Function name**: `invoke-supervisor-agent`
4. **Runtime**: Python 3.12
5. **Create function**
6. En **Code** → **Upload from** → **.zip file** → Sube `invoke-supervisor-agent.zip`
7. **Configuration** → **Environment variables** → **Edit** → **Add environment variables**:
   - `SUPERVISOR_AGENT_ID` = `KT1W7DMYOR`
   - `SUPERVISOR_AGENT_ALIAS_ID` = `PLACEHOLDER`
8. **Configuration** → **General configuration** → **Edit**:
   - **Timeout**: `300` segundos (5 minutos)
   - **Save**
9. **Configuration** → **Permissions** → Clic en el **Role name** (abre IAM)
10. En IAM → **Add permissions** → **Create inline policy** → **JSON**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "bedrock:InvokeAgent",
    "Resource": "arn:aws:bedrock:us-east-1:*:agent-alias/*/*"
  }]
}
```
11. **Review policy** → Name: `BedrockInvokePolicy` → **Create policy**

---

## Lambda 2: bedrock-asis-lambda

1. **Create function**
2. **Function name**: `bedrock-asis-lambda`
3. **Runtime**: Python 3.12
4. **Create function**
5. Upload `bedrock-asis-lambda.zip`
6. **Environment variables**:
   - `S3_BUCKET` = `poc-code-analyzer-2026`
7. **Timeout**: `300` segundos
8. **Permissions** → Inline policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:PutObject",
    "Resource": "arn:aws:s3:::poc-code-analyzer-2026/documentos-generados/*"
  }]
}
```

---

## Lambda 3: bedrock-tobe-lambda

Igual que Lambda 2:
- **Function name**: `bedrock-tobe-lambda`
- Upload `bedrock-tobe-lambda.zip`
- **Environment variable**: `S3_BUCKET` = `poc-code-analyzer-2026`
- **Timeout**: `300` segundos
- Mismo inline policy de S3

---

## Siguiente paso:

Una vez desplegadas las 3 Lambdas, configura los Action Groups en los agentes de Bedrock.
