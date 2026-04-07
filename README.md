# PoC — Plataforma de Análisis Agéntico de Código
## Arquitectura multi-agente con AWS Bedrock

---

## Estructura del proyecto

```
poc-code-analyzer/
├── invoke-supervisor-agent.py   # Lambda de entrada — recibe URL del repo e invoca al Supervisor Agent
├── bedrock-asis-lambda.py       # Lambda del Agente AS-IS — genera documento de estado actual
├── bedrock-tobe-lambda.py       # Lambda del Agente TO-BE — genera propuesta de modernización
└── README.md
```

---

## Flujo de ejecución

```
Usuario (API Gateway)
        │
        ▼
invoke-supervisor-agent.py      ← Lambda de entrada
        │
        ▼
Supervisor Agent (Bedrock)      ← Lee el repo con MCP GitHub, construye contexto
        │
        ├──────────────────────────────────┐
        ▼                                  ▼
Agente AS-IS (Bedrock)          Agente TO-BE (Bedrock)
        │                                  │
        ▼                                  ▼
bedrock-asis-lambda.py          bedrock-tobe-lambda.py
        │                                  │
        ▼                                  ▼
  S3: asis-{ts}.txt               S3: tobe-{ts}.txt
```

---

## Configuración paso a paso

### 1. Bucket S3

Crea un bucket S3 y reemplaza `ADD-YOUR-BUCKET-NAME` en los tres archivos Lambda:
- `bedrock-asis-lambda.py` → variable `S3_BUCKET`
- `bedrock-tobe-lambda.py` → variable `S3_BUCKET`

El bucket debe tener esta estructura de prefijos (se crean automáticamente):
```
documentos-generados/
  ├── asis/     ← documentos AS-IS generados
  └── tobe/     ← documentos TO-BE generados
```

### 2. Agentes en AWS Bedrock

Crea tres agentes en AWS Bedrock Console:

#### Agente Supervisor
- **Nombre sugerido**: `code-analyzer-supervisor`
- **Modelo**: Claude Sonnet 3.5 (o Claude Haiku para menor costo en PoC)
- **Instrucciones**: ver prompt "Agente Supervisor" en la documentación
- **Sub-agentes colaboradores**: AS-IS Agent y TO-BE Agent
- **MCP Tool**: configurar `@modelcontextprotocol/server-github` con token de GitHub

#### Agente AS-IS
- **Nombre sugerido**: `code-analyzer-asis`
- **Modelo**: Claude Sonnet 3.5
- **Instrucciones**: ver prompt "Agente AS-IS" en la documentación
- **Action Group**: `asis-document-action-group`
  - Función: `generar-documento-asis`
  - Lambda: `bedrock-asis-lambda`

#### Agente TO-BE
- **Nombre sugerido**: `code-analyzer-tobe`
- **Modelo**: Claude Sonnet 3.5
- **Instrucciones**: ver prompt "Agente TO-BE" en la documentación
- **Action Group**: `tobe-document-action-group`
  - Función: `generar-documento-tobe`
  - Lambda: `bedrock-tobe-lambda`

### 3. Lambda de entrada (invoke-supervisor-agent.py)

Reemplaza en el archivo:
```python
SUPERVISOR_AGENT_ID       = "ADD-YOUR-SUPERVISOR-AGENT-ID"
SUPERVISOR_AGENT_ALIAS_ID = "ADD-YOUR-SUPERVISOR-AGENT-ALIAS-ID"
```

### 4. IAM — Permisos necesarios

Cada Lambda necesita un rol IAM con estas políticas:

**invoke-supervisor-agent** (Lambda de entrada):
```json
{
  "Effect": "Allow",
  "Action": ["bedrock:InvokeAgent"],
  "Resource": "arn:aws:bedrock:*:*:agent-alias/*/*"
}
```

**bedrock-asis-lambda y bedrock-tobe-lambda**:
```json
{
  "Effect": "Allow",
  "Action": ["s3:PutObject"],
  "Resource": "arn:aws:s3:::ADD-YOUR-BUCKET-NAME/documentos-generados/*"
}
```

---

## Cómo invocar el PoC

### Via API Gateway (POST) o prueba directa en Lambda:

```json
{
  "body": "{\"repo_url\": \"https://github.com/owner/repo\", \"sessionId\": \"session-001\"}"
}
```

### Via AWS CLI:

```bash
aws lambda invoke \
  --function-name invoke-supervisor-agent \
  --payload '{"body": "{\"repo_url\": \"https://github.com/spring-projects/spring-petclinic\", \"sessionId\": \"test-001\"}"}' \
  --cli-binary-format raw-in-base64-out \
  output.json && cat output.json
```

---

## Parámetros que reciben las Lambdas de documentos

### bedrock-asis-lambda.py — función `generar-documento-asis`

| Parámetro            | Descripción                                      |
|----------------------|--------------------------------------------------|
| `repo_url`           | URL del repositorio analizado                    |
| `stack_actual`       | Lenguajes, frameworks y versiones detectados     |
| `patron_arquitectura`| Monolito, microservicios, event-driven, etc.     |
| `componentes`        | Módulos y servicios principales                  |
| `dependencias`       | APIs externas, DBs, colas identificadas          |
| `infraestructura`    | Docker, CI/CD, IaC — lo que exista              |
| `riesgos`            | Deuda técnica, EOL, ausencia de tests            |

### bedrock-tobe-lambda.py — función `generar-documento-tobe`

| Parámetro             | Descripción                                      |
|-----------------------|--------------------------------------------------|
| `repo_url`            | URL del repositorio analizado                    |
| `tecnologias_eol`     | Tecnologías sin soporte detectadas               |
| `stack_objetivo`      | Stack moderno propuesto                          |
| `estrategia_migracion`| Strangler Fig, Big Bang, o híbrido               |
| `fases`               | Desglose de la migración por fases               |
| `quick_wins`          | Mejoras de bajo esfuerzo y alto impacto          |
| `riesgos_migracion`   | Riesgos del proceso de migración                 |

---

## Notas del PoC

- Los documentos se generan como archivos `.txt` estructurados en S3. En producción se reemplaza por el motor de plantillas DOCX.
- El Supervisor Agent necesita acceso al plugin MCP de GitHub — requiere configurar un GitHub Personal Access Token en Secrets Manager.
- `sessionId` permite mantener contexto de conversación entre múltiples invocaciones del mismo usuario.
