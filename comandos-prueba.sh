#!/bin/bash

# ============================================
# PRUEBAS DE LAMBDAS
# ============================================

echo "=== Prueba Lambda lee-repositorio ==="
aws lambda invoke \
  --function-name lee-repositorio-lambda \
  --payload '{"actionGroup":"leer-repositorio-action-group","function":"leer-repositorio","parameters":[{"name":"repo_url","type":"string","value":"https://github.com/spring-projects/spring-petclinic"}]}' \
  --cli-binary-format raw-in-base64-out \
  output-lee-repo.json && cat output-lee-repo.json

echo -e "\n\n=== Prueba Lambda AS-IS ==="
aws lambda invoke \
  --function-name bedrock-asis-lambda \
  --payload '{"actionGroup":"asis-action-group","function":"generar-documento-asis","parameters":[{"name":"stack_actual","value":"Java 17, Spring Boot 4.0.3"},{"name":"patron_arquitectura","value":"Monolito MVC"},{"name":"componentes","value":"OwnerController, PetController"},{"name":"dependencias","value":"Spring Data JPA, MySQL"},{"name":"riesgos","value":"Sin Docker, sin CI/CD"}]}' \
  --cli-binary-format raw-in-base64-out \
  output-asis.json && cat output-asis.json

echo -e "\n\n=== Prueba Lambda TO-BE ==="
aws lambda invoke \
  --function-name bedrock-tobe-lambda \
  --payload '{"actionGroup":"tobe-action-group","function":"generar-documento-tobe","parameters":[{"name":"stack_objetivo","value":"Java 21, Spring Boot 3.x"},{"name":"estrategia_migracion","value":"Strangler Fig"},{"name":"fases","value":"Fase 1: Contenedores, Fase 2: Microservicios"},{"name":"quick_wins","value":"Agregar Docker, CI/CD"},{"name":"riesgos_migracion","value":"Regresión en pagos"}]}' \
  --cli-binary-format raw-in-base64-out \
  output-tobe.json && cat output-tobe.json

# ============================================
# PRUEBAS DE AGENTES BEDROCK
# ============================================

echo -e "\n\n=== Prueba Agente AS-IS ==="
python3 -c "
import boto3
client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
response = client.invoke_agent(
    agentId='UXABHLE263',
    agentAliasId='TSTALIASID',
    sessionId='test-asis-$(date +%s)',
    inputText='''Genera el documento AS-IS con esta información:
stack_actual: Java 17, Spring Boot 4.0.3, Thymeleaf, Maven, H2/MySQL
patron_arquitectura: Monolito MVC en capas Controller-Service-Repository
componentes: OwnerController, PetController, VisitController, VetController, WelcomeController
dependencias: Spring Data JPA, Thymeleaf, Spring Actuator, H2, MySQL
riesgos: Sin Docker, sin CI/CD, cobertura de tests baja'''
)
for event in response['completion']:
    if 'chunk' in event:
        print(event['chunk']['bytes'].decode('utf-8'), end='')
print()
"

echo -e "\n\n=== Prueba Agente TO-BE ==="
python3 -c "
import boto3
client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
response = client.invoke_agent(
    agentId='YQQVX1FP3V',
    agentAliasId='TSTALIASID',
    sessionId='test-tobe-$(date +%s)',
    inputText='''Genera el documento TO-BE con esta información:
stack_objetivo: Java 21, Spring Boot 3.x, Docker, Kubernetes, PostgreSQL
estrategia_migracion: Strangler Fig — migración incremental por módulos
fases: Fase 1 Contenedores. Fase 2 Microservicios. Fase 3 CI/CD. Fase 4 Observabilidad
quick_wins: Actualizar Java 17 a Java 21, agregar Dockerfile, agregar GitHub Actions, agregar tests JUnit 5
riesgos_migracion: Riesgo de regresión en módulo de pagos, migración de H2 a PostgreSQL en producción'''
)
for event in response['completion']:
    if 'chunk' in event:
        print(event['chunk']['bytes'].decode('utf-8'), end='')
print()
"

echo -e "\n\n=== Prueba Agente SUPERVISOR ==="
python3 -c "
import boto3
client = boto3.client('bedrock-agent-runtime', region_name='us-east-1')
response = client.invoke_agent(
    agentId='KT1W7DMYOR',
    agentAliasId='TSTALIASID',
    sessionId='test-supervisor-$(date +%s)',
    inputText='Analiza el repositorio https://github.com/spring-projects/spring-petclinic y genera los documentos AS-IS y TO-BE.'
)
for event in response['completion']:
    if 'chunk' in event:
        print(event['chunk']['bytes'].decode('utf-8'), end='')
print()
"
