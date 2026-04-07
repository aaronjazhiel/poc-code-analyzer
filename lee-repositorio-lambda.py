import json
import boto3
import urllib.request
import urllib.error
import base64
import time

SECRET_NAME = "bedrock/github-token"
GITHUB_API  = "https://api.github.com"

ASIS_AGENT_ID    = "UXABHLE263"
ASIS_ALIAS_ID    = "TSTALIASID"
TOBE_AGENT_ID    = "YQQVX1FP3V"
TOBE_ALIAS_ID    = "TSTALIASID"


def get_github_token():
    client = boto3.client("secretsmanager", region_name="us-east-1")
    secret = client.get_secret_value(SecretId=SECRET_NAME)
    return json.loads(secret["SecretString"])["token"]


def github_get(path, token):
    url = f"{GITHUB_API}{path}"
    req = urllib.request.Request(url, headers={
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "poc-code-analyzer"
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code} en {path}")
        return None
    except Exception as e:
        print(f"Error en {path}: {e}")
        return None


def get_file_content(owner, repo, path, token):
    data = github_get(f"/repos/{owner}/{repo}/contents/{path}", token)
    if not data or "content" not in data:
        return None
    try:
        return base64.b64decode(data["content"]).decode("utf-8", errors="ignore")
    except Exception:
        return None


def get_tree(owner, repo, token):
    data = github_get(f"/repos/{owner}/{repo}/git/trees/HEAD?recursive=1", token)
    if not data:
        return []
    return [item["path"] for item in data.get("tree", []) if item["type"] == "blob"]


def filter_classes(paths, pattern, max_files=5):
    return [p for p in paths if p.endswith(f"{pattern}.java")][:max_files]


def extract_dependencies(pom_content):
    if not pom_content:
        return []
    deps = []
    keywords = ["spring-boot", "postgresql", "mysql", "db2", "jwt", "security",
                "kafka", "redis", "feign", "swagger", "openapi", "mapstruct",
                "lombok", "jacoco", "mockito", "junit", "docker", "kubernetes"]
    for line in pom_content.split("\n"):
        line = line.strip()
        if "<artifactId>" in line:
            artifact = line.replace("<artifactId>", "").replace("</artifactId>", "").strip()
            if any(k in artifact.lower() for k in keywords):
                deps.append(artifact)
    return list(set(deps))


def detect_risks(all_files, pom_content, app_props, languages):
    risks = []
    if pom_content:
        if "1.8" in pom_content or "<java.version>8" in pom_content:
            risks.append("Java 1.8 EOL — migración urgente a Java 21 LTS")
        elif "<java.version>11" in pom_content:
            risks.append("Java 11 — considerar migración a Java 21 LTS")
        if "2.7." in pom_content or "2.6." in pom_content:
            risks.append("Spring Boot 2.x EOL — migrar a Spring Boot 3.x")
    test_files = [f for f in all_files if "test" in f.lower() and f.endswith(".java")]
    if len(test_files) == 0:
        risks.append("Sin tests unitarios detectados — riesgo alto de regresión")
    elif len(test_files) < 5:
        risks.append(f"Cobertura de tests baja — solo {len(test_files)} archivos de test")
    docker_files = [f for f in all_files if "dockerfile" in f.lower() or "docker-compose" in f.lower()]
    if not docker_files:
        risks.append("Sin Dockerfile ni docker-compose — no containerizado")
    cicd_files = [f for f in all_files if ".github/workflows" in f or "jenkins" in f.lower()]
    if not cicd_files:
        risks.append("Sin pipeline CI/CD detectado")
    if pom_content and "db2" in pom_content.lower():
        risks.append("DB2 — base de datos legacy, considerar migración a PostgreSQL")
    return risks


def detect_pattern(all_files, controllers, services, repositories):
    has_k8s   = any("k8s" in f or "kubernetes" in f for f in all_files)
    has_docker = any("dockerfile" in f.lower() for f in all_files)
    if len(controllers) > 0 and len(repositories) > 0:
        pattern = "Monolito MVC en capas (Controller → Service → Repository)"
    elif len(services) > 0 and len(controllers) == 0:
        pattern = "Arquitectura de servicios batch/flujo sin capa REST"
    else:
        pattern = "Monolito modular"
    infra = []
    if has_docker:
        infra.append("Docker")
    if has_k8s:
        infra.append("Kubernetes")
    cicd = [f for f in all_files if ".github/workflows" in f]
    if cicd:
        infra.append(f"CI/CD GitHub Actions ({len(cicd)} workflows)")
    return pattern, infra


def leer_repositorio(repo_url, token):
    parts = repo_url.rstrip("/").replace("https://github.com/", "").replace(".git", "").split("/")
    owner, repo = parts[0], parts[1]
    print(f"Leyendo: {owner}/{repo}")

    repo_info  = github_get(f"/repos/{owner}/{repo}", token) or {}
    languages  = github_get(f"/repos/{owner}/{repo}/languages", token) or {}
    readme     = get_file_content(owner, repo, "README.md", token) or "No disponible"
    pom        = get_file_content(owner, repo, "pom.xml", token)
    gradle     = get_file_content(owner, repo, "build.gradle", token)
    app_props  = (
        get_file_content(owner, repo, "src/main/resources/application.properties", token) or
        get_file_content(owner, repo, "src/main/resources/application.yml", token) or
        "No disponible"
    )
    build_file = pom or gradle or ""
    build_type = "pom.xml" if pom else ("build.gradle" if gradle else "No detectado")
    all_files  = get_tree(owner, repo, token)
    controllers  = filter_classes(all_files, "Controller")
    services     = filter_classes(all_files, "Service")
    repositories = filter_classes(all_files, "Repository")
    dependencies = extract_dependencies(build_file)
    risks        = detect_risks(all_files, build_file, app_props, languages)
    pattern, infra = detect_pattern(all_files, controllers, services, repositories)

    java_version   = "No detectado"
    spring_version = "No detectado"
    if build_file:
        for line in build_file.split("\n"):
            if "java.version" in line and java_version == "No detectado":
                java_version = line.strip().replace("<java.version>","").replace("</java.version>","").strip()
        lines = build_file.split("\n")
        for i, line in enumerate(lines):
            if "spring-boot-starter-parent" in line:
                for j in range(i, min(i+5, len(lines))):
                    if "<version>" in lines[j]:
                        spring_version = lines[j].strip().replace("<version>","").replace("</version>","").strip()
                        break

    controller_names = [f.split("/")[-1].replace(".java","") for f in controllers]
    service_names    = [f.split("/")[-1].replace(".java","") for f in services]
    repo_names       = [f.split("/")[-1].replace(".java","") for f in repositories]
    test_files       = [f for f in all_files if "test" in f.lower() and f.endswith(".java")]

    return {
        "owner": owner,
        "repo": repo,
        "stack_actual": f"Lenguajes: {', '.join(languages.keys()) if languages else 'No detectado'}. Java: {java_version}. Spring Boot: {spring_version}. Build: {build_type}. Dependencias: {', '.join(dependencies) if dependencies else 'No detectadas'}",
        "patron_arquitectura": pattern,
        "infraestructura": ', '.join(infra) if infra else 'Sin Docker, sin CI/CD, sin Kubernetes',
        "componentes": f"Controllers ({len(controllers)}): {', '.join(controller_names) or 'Ninguno'}. Services ({len(services)}): {', '.join(service_names) or 'Ninguno'}. Repositories ({len(repositories)}): {', '.join(repo_names) or 'Ninguno'}. Tests: {len(test_files)} archivos",
        "dependencias": ', '.join(dependencies) if dependencies else 'No detectadas',
        "riesgos": '. '.join(risks) if risks else 'Sin riesgos críticos detectados',
        "app_props": app_props[:400]
    }


def invocar_agente(agent_id, alias_id, session_id, input_text):
    client = boto3.client("bedrock-agent-runtime", region_name="us-east-1")
    response = client.invoke_agent(
        agentId=agent_id,
        agentAliasId=alias_id,
        sessionId=session_id,
        inputText=input_text
    )
    result = ""
    for event in response.get("completion", []):
        if "chunk" in event and "bytes" in event["chunk"]:
            result += event["chunk"]["bytes"].decode("utf-8")
    return result


def lambda_handler(event, context):
    print("Orquestador Lambda iniciado")
    try:
        if isinstance(event.get("body"), str):
            data = json.loads(event["body"])
        else:
            data = event.get("body", event)

        repo_url = data.get("repo_url", "").strip()
        if not repo_url:
            return {"statusCode": 400, "body": json.dumps({"error": "Se requiere repo_url"})}

        token = get_github_token()

        # PASO 1 — Leer repositorio
        print("PASO 1: Leyendo repositorio...")
        ctx = leer_repositorio(repo_url, token)
        print(f"Repositorio leído: {ctx['owner']}/{ctx['repo']}")

        session_ts = str(int(time.time()))

        # PASO 2 — Invocar AS-IS Agent
        print("PASO 2: Invocando AS-IS Agent...")
        asis_input = f"""Genera el documento AS-IS con esta información:
stack_actual: {ctx['stack_actual']}
patron_arquitectura: {ctx['patron_arquitectura']}. Infraestructura: {ctx['infraestructura']}
componentes: {ctx['componentes']}
dependencias: {ctx['dependencias']}
riesgos: {ctx['riesgos']}"""

        asis_response = invocar_agente(
            ASIS_AGENT_ID, ASIS_ALIAS_ID,
            f"asis-{session_ts}",
            asis_input
        )
        print(f"AS-IS response: {asis_response}")
        
        # Extraer nombre de archivo del response
        asis_file = ""
        if "asis-" in asis_response:
            import re
            match = re.search(r'asis-\d{8}-\d{6}\.docx', asis_response)
            if match:
                asis_file = match.group(0)

        # PASO 3 — Invocar TO-BE Agent
        print("PASO 3: Invocando TO-BE Agent...")
        tobe_input = f"""Genera el documento TO-BE con esta información del repositorio {ctx['repo']}:
stack_objetivo: Basado en {ctx['stack_actual']} — propón modernización a Java 21, Spring Boot 3.x, Docker, Kubernetes
estrategia_migracion: Basado en {ctx['patron_arquitectura']} — determina Strangler Fig o Big Bang
fases: Define fases de migración basadas en los riesgos: {ctx['riesgos']}
quick_wins: Mejoras inmediatas basadas en: {ctx['riesgos']}
riesgos_migracion: Riesgos del proceso de modernización basados en: {ctx['riesgos']}"""

        tobe_response = invocar_agente(
            TOBE_AGENT_ID, TOBE_ALIAS_ID,
            f"tobe-{session_ts}",
            tobe_input
        )
        print(f"TO-BE response: {tobe_response}")
        
        # Extraer nombre de archivo del response
        tobe_file = ""
        if "tobe-" in tobe_response:
            import re
            match = re.search(r'tobe-\d{8}-\d{6}\.docx', tobe_response)
            if match:
                tobe_file = match.group(0)

        return {
            "statusCode": 200,
            "body": json.dumps({
                "repo": f"{ctx['owner']}/{ctx['repo']}",
                "asis_response": asis_response,
                "tobe_response": tobe_response,
                "asis_document": asis_file,
                "tobe_document": tobe_file
            }, ensure_ascii=False)
        }

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}