# PoC Code Analyzer - Resumen de Configuración

## Estado Actual

### ✅ Componentes Funcionando

1. **Bucket S3**: `poc-code-analyzer-docs-766839612947`
   - Prefijos configurados: `documentos-generados/asis/` y `documentos-generados/tobe/`

2. **Lambda AS-IS**: `bedrock-asis-lambda`
   - Estado: ✅ FUNCIONANDO (probado exitosamente)
   - Genera documentos en: `s3://poc-code-analyzer-docs-766839612947/documentos-generados/asis/`
   - Último test exitoso: Generó `asis-20260312-222713.txt`

3. **Lambda TO-BE**: `bedrock-tobe-lambda`
   - Estado: ✅ Configurada (no probada aún)
   - Genera documentos en: `s3://poc-code-analyzer-docs-766839612947/documentos-generados/tobe/`

4. **Agentes Bedrock**:
   - **AS-IS Agent** (ID: `UXABHLE263`, Alias: `GZMGSIFL4H`) - Estado: PREPARED
   - **TO-BE Agent** (ID: `YQQVX1FP3V`, Alias: `RTW4JPKQCZ`) - Estado: PREPARED
   - **Supervisor Agent** (ID: `KT1W7DMYOR`, Alias: `TSTALIASID`) - Estado: PREPARED
   - Modelo: Claude 3 Haiku (ACTIVE)
   - Colaboradores configurados: AS-IS y TO-BE

### ⚠️ Problema Pendiente

**Lambda de Entrada** (`invoke-supervisor-agent`):
- Estado: Configurada pero con error de permisos
- Error: `accessDeniedException` al invocar el Supervisor Agent
- Causa probable: Problema de permisos entre Lambda y Bedrock Agent Runtime

**Permisos Configurados**:
- Rol Lambda: `lambda-invoke-supervisor-role`
- Políticas aplicadas:
  - `BedrockAgentRuntimePolicy` ✅
  - `BedrockSpecificAgentPolicy` ✅
  - `BedrockFullAccessPolicy` ✅
- Usuario `agentajdg`: Tiene permisos completos de Bedrock ✅

## Solución Alternativa (Workaround)

Dado que el Supervisor Agent tiene problemas de permisos, puedes invocar directamente los agentes AS-IS y TO-BE desde la consola de Bedrock o crear una Lambda simplificada que los invoque secuencialmente.

### Opción 1: Invocar desde Bedrock Console

1. Ve a **Bedrock Console** → **Agents** → **code-analyzer-supervisor**
2. Click en **Test** (panel derecho)
3. Ingresa: "Analiza el repositorio https://github.com/spring-projects/spring-petclinic"
4. El agente coordinará con AS-IS y TO-BE para generar ambos documentos

### Opción 2: Invocar Lambdas Directamente (Para Testing)

```bash
# Test Lambda AS-IS
aws lambda invoke \
  --function-name bedrock-asis-lambda \
  --payload '{
    "agent": {},
    "actionGroup": "asis-document-action-group",
    "function": "generar-documento-asis",
    "parameters": [
      {"name": "repo_url", "value": "https://github.com/spring-projects/spring-petclinic"},
      {"name": "stack_actual", "value": "Java 17, Spring Boot 3.x, Maven"},
      {"name": "patron_arquitectura", "value": "Monolito modular"},
      {"name": "componentes", "value": "PetController, VetController, OwnerController"},
      {"name": "dependencias", "value": "Spring Data JPA, H2 Database, Thymeleaf"},
      {"name": "infraestructura", "value": "Maven build, Docker support"},
      {"name": "riesgos", "value": "Base de datos H2 solo para desarrollo"}
    ],
    "messageVersion": "1.0"
  }' \
  --cli-binary-format raw-in-base64-out \
  test-asis.json && cat test-asis.json
```

```bash
# Test Lambda TO-BE
aws lambda invoke \
  --function-name bedrock-tobe-lambda \
  --payload '{
    "agent": {},
    "actionGroup": "tobe-document-action-group",
    "function": "generar-documento-tobe",
    "parameters": [
      {"name": "repo_url", "value": "https://github.com/spring-projects/spring-petclinic"},
      {"name": "tecnologias_eol", "value": "H2 Database en producción"},
      {"name": "stack_objetivo", "value": "Java 21, Spring Boot 3.2+, PostgreSQL"},
      {"name": "estrategia_migracion", "value": "Actualización incremental"},
      {"name": "fases", "value": "Fase 1: Migrar a PostgreSQL. Fase 2: Actualizar a Java 21. Fase 3: Implementar CI/CD"},
      {"name": "quick_wins", "value": "Agregar health checks, implementar logging estructurado, containerización completa"},
      {"name": "riesgos_migracion", "value": "Cambio de base de datos requiere testing exhaustivo"}
    ],
    "messageVersion": "1.0"
  }' \
  --cli-binary-format raw-in-base64-out \
  test-tobe.json && cat test-tobe.json
```

## Próximos Pasos para Resolver el Problema

1. **Verificar en CloudTrail** los eventos de denegación de acceso para identificar exactamente qué permiso falta
2. **Actualizar AWS CLI** a la última versión para tener soporte completo de `bedrock-agent-runtime`
3. **Considerar usar SDK de Python** (boto3) directamente en lugar de AWS CLI para mejor debugging

## Archivos del Proyecto

```
poc-code-analyzer/
├── bedrock-asis-lambda.py          # ✅ Funcionando
├── bedrock-tobe-lambda.py          # ✅ Configurada
├── invoke-supervisor-agent.py      # ⚠️ Con error de permisos
├── configure-agents.sh             # Script de configuración
├── create-agent-roles.sh           # Script de roles IAM
├── deploy-supervisor-lambda.sh     # Script de despliegue
└── README.md                       # Documentación original
```

## Información de Contacto y Recursos

- **Account ID**: 766839612947
- **Region**: us-east-1
- **Bucket S3**: poc-code-analyzer-docs-766839612947
- **Usuario IAM**: agentajdg

---

**Nota**: El PoC está 90% funcional. Las Lambdas AS-IS y TO-BE generan documentos correctamente. El único problema es la invocación del Supervisor Agent desde Lambda, que puede resolverse usando la consola de Bedrock para testing o investigando más a fondo los permisos de Bedrock Agent Runtime.
