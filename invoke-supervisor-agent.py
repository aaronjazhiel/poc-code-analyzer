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


def filter_java_classes(paths, pattern, max_files=5):
    matched = [p for p in paths if p.endswith(f"{pattern}.java")]
    return matched[:max_files]


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

        build_file = pom or gradle or "No disponible"
        build_type = "pom.xml" if pom else ("build.gradle" if gradle else "No detectado")

        all_files    = get_tree(owner, repo, token)
        controllers  = filter_java_classes(all_files, "Controller")
        services     = filter_java_classes(all_files, "Service")
        repositories = filter_java_classes(all_files, "Repository")

        controller_contents = {}
        for f in controllers:
            c = get_file_content(owner, repo, f, token)
            if c:
                controller_contents[f] = c[:1500]

        service_contents = {}
        for f in services:
            c = get_file_content(owner, repo, f, token)
            if c:
                service_contents[f] = c[:1500]

        repo_contents = {}
        for f in repositories:
            c = get_file_content(owner, repo, f, token)
            if c:
                repo_contents[f] = c[:1500]

        contexto = f"""
=== CONTEXTO DEL REPOSITORIO: {owner}/{repo} ===

METADATA:
- Nombre: {repo_info.get('name', repo)}
- Descripción: {repo_info.get('description', 'No disponible')}
- Lenguajes: {', '.join(languages.keys()) if languages else 'No detectado'}
- Archivo de build: {build_type}

README (primeros 1000 chars):
{readme[:1000]}

ARCHIVO DE BUILD ({build_type}):
{build_file[:2000]}

APPLICATION PROPERTIES:
{app_props[:500]}

CONTROLLERS ({len(controllers)}): {', '.join(controllers)}
CONTENIDO CONTROLLERS:
{json.dumps(controller_contents, indent=2, ensure_ascii=False)[:3000]}

SERVICES ({len(services)}): {', '.join(services)}
CONTENIDO SERVICES:
{json.dumps(service_contents, indent=2, ensure_ascii=False)[:3000]}

REPOSITORIES ({len(repositories)}): {', '.join(repositories)}
CONTENIDO REPOSITORIES:
{json.dumps(repo_contents, indent=2, ensure_ascii=False)[:2000]}

ESTRUCTURA (primeros 50 archivos):
{chr(10).join(all_files[:50])}
""".strip()

        print(f"Contexto construido: {len(contexto)} chars")

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
                            "contexto": contexto
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