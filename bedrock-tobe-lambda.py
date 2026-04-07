import json
import boto3
import urllib.request
import urllib.error
import base64

SECRET_NAME = "bedrock/github-token"
GITHUB_API  = "https://api.github.com"


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
    """Extrae dependencias clave del pom.xml"""
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

    # Java version
    if pom_content:
        if "1.8" in pom_content or "java.version>1.8" in pom_content or "<java.version>8" in pom_content:
            risks.append("Java 1.8 EOL — migración urgente a Java 21 LTS")
        elif "java.version>11" in pom_content or "<java.version>11" in pom_content:
            risks.append("Java 11 — considerar migración a Java 21 LTS")
        if "2.7." in pom_content or "2.6." in pom_content:
            risks.append("Spring Boot 2.x EOL — migrar a Spring Boot 3.x")

    # Tests
    test_files = [f for f in all_files if "test" in f.lower() and f.endswith(".java")]
    if len(test_files) == 0:
        risks.append("Sin tests unitarios detectados — riesgo alto de regresión")
    elif len(test_files) < 5:
        risks.append(f"Cobertura de tests baja — solo {len(test_files)} archivos de test")

    # Docker
    docker_files = [f for f in all_files if "dockerfile" in f.lower() or "docker-compose" in f.lower()]
    if not docker_files:
        risks.append("Sin Dockerfile ni docker-compose — no containerizado")

    # CI/CD
    cicd_files = [f for f in all_files if ".github/workflows" in f or "jenkins" in f.lower() or "gitlab-ci" in f.lower()]
    if not cicd_files:
        risks.append("Sin pipeline CI/CD detectado")

    # DB2
    if pom_content and "db2" in pom_content.lower():
        risks.append("DB2 — base de datos legacy, considerar migración a PostgreSQL")

    return risks


def detect_pattern(all_files, controllers, services, repositories):
    has_controllers = len(controllers) > 0
    has_services = len(services) > 0
    has_repos = len(repositories) > 0
    has_k8s = any("k8s" in f or "kubernetes" in f for f in all_files)
    has_docker = any("dockerfile" in f.lower() for f in all_files)

    if has_controllers and has_services and has_repos:
        pattern = "Monolito MVC en capas (Controller → Service → Repository)"
    elif has_services and not has_controllers:
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


def lambda_handler(event, context):
    print("lee-repositorio Lambda iniciada")
    try:
        param_dict = {p["name"]: p["value"] for p in event.get("parameters", [])}
        repo_url = param_dict.get("repo_url", "").strip()

        if not repo_url:
            if isinstance(event.get("body"), str):
                data = json.loads(event["body"])
            else:
                data = event.get("body", event)
            repo_url = data.get("repo_url", "").strip()

        if not repo_url:
            return _error_response(event, "Se requiere repo_url")

        parts = repo_url.rstrip("/").replace("https://github.com/", "").split("/")
        if len(parts) < 2:
            return _error_response(event, "URL de GitHub inválida")

        owner, repo = parts[0], parts[1]
        print(f"Analizando: {owner}/{repo}")

        token = get_github_token()

        repo_info = github_get(f"/repos/{owner}/{repo}", token) or {}
        languages = github_get(f"/repos/{owner}/{repo}/languages", token) or {}

        readme    = get_file_content(owner, repo, "README.md", token) or "No disponible"
        pom       = get_file_content(owner, repo, "pom.xml", token)
        gradle    = get_file_content(owner, repo, "build.gradle", token)
        app_props = (
            get_file_content(owner, repo, "src/main/resources/application.properties", token) or
            get_file_content(owner, repo, "src/main/resources/application.yml", token) or
            "No disponible"
        )

        build_file = pom or gradle or ""
        build_type = "pom.xml" if pom else ("build.gradle" if gradle else "No detectado")

        all_files    = get_tree(owner, repo, token)
        controllers  = filter_classes(all_files, "Controller")
        services     = filter_classes(all_files, "Service")
        repositories = filter_classes(all_files, "Repository")

        # Extraer info clave
        dependencies = extract_dependencies(build_file)
        risks        = detect_risks(all_files, build_file, app_props, languages)
        pattern, infra = detect_pattern(all_files, controllers, services, repositories)

        # Extraer versión Java
        java_version = "No detectado"
        if build_file:
            for line in build_file.split("\n"):
                if "java.version" in line:
                    java_version = line.strip().replace("<java.version>","").replace("</java.version>","").strip()
                    break

        # Extraer versión Spring Boot
        spring_version = "No detectado"
        if build_file:
            lines = build_file.split("\n")
            for i, line in enumerate(lines):
                if "spring-boot-starter-parent" in line:
                    for j in range(i, min(i+5, len(lines))):
                        if "<version>" in lines[j]:
                            spring_version = lines[j].strip().replace("<version>","").replace("</version>","").strip()
                            break

        # Nombres de clases reales
        controller_names = [f.split("/")[-1].replace(".java","") for f in controllers]
        service_names    = [f.split("/")[-1].replace(".java","") for f in services]
        repo_names       = [f.split("/")[-1].replace(".java","") for f in repositories]

        test_files = [f for f in all_files if "test" in f.lower() and f.endswith(".java")]

        resumen = f"""
=== ANÁLISIS DEL REPOSITORIO: {owner}/{repo} ===

DESCRIPCIÓN:
{repo_info.get('description', 'No disponible')}

STACK TECNOLÓGICO ACTUAL:
- Lenguajes: {', '.join(languages.keys()) if languages else 'No detectado'}
- Java version: {java_version}
- Spring Boot: {spring_version}
- Archivo de build: {build_type}
- Dependencias clave: {', '.join(dependencies) if dependencies else 'No detectadas'}

PATRÓN ARQUITECTÓNICO:
{pattern}

INFRAESTRUCTURA ACTUAL:
{', '.join(infra) if infra else 'Sin Docker, sin CI/CD, sin Kubernetes detectado'}

COMPONENTES PRINCIPALES:
- Controllers ({len(controllers)}): {', '.join(controller_names) if controller_names else 'Ninguno detectado'}
- Services ({len(services)}): {', '.join(service_names) if service_names else 'Ninguno detectado'}
- Repositories ({len(repositories)}): {', '.join(repo_names) if repo_names else 'Ninguno detectado'}
- Archivos de test: {len(test_files)} encontrados

APPLICATION PROPERTIES (extracto):
{app_props[:400]}

RIESGOS DETECTADOS:
{chr(10).join(f'- {r}' for r in risks) if risks else '- Sin riesgos críticos detectados'}

ESTRUCTURA DEL PROYECTO (primeros 40 archivos):
{chr(10).join(all_files[:40])}
""".strip()

        print(f"Resumen construido: {len(resumen)} chars")

        action_response = {
            "agent": event.get("agent", {}),
            "actionGroup": event.get("actionGroup", ""),
            "function": event.get("function", ""),
            "functionResponse": {
                "responseBody": {
                    "TEXT": {
                        "body": json.dumps({
                            "status": "ok",
                            "owner": owner,
                            "repo": repo,
                            "resumen": resumen
                        }, ensure_ascii=False)
                    }
                }
            }
        }
        return {"response": action_response, "messageVersion": event.get("messageVersion", "1.0")}

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        return _error_response(event, str(e))


def _error_response(event, message):
    return {
        "response": {
            "actionGroup": event.get("actionGroup", ""),
            "function": event.get("function", ""),
            "functionResponse": {
                "responseBody": {
                    "TEXT": {"body": json.dumps({"error": message})}
                }
            }
        },
        "messageVersion": event.get("messageVersion", "1.0")
    }