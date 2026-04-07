from flask import Flask, render_template, request, jsonify, send_file
import boto3
import json
import time
import os

app = Flask(__name__)

# Configuración AWS
lambda_client = boto3.client('lambda', region_name='us-east-1')
s3_client = boto3.client('s3', region_name='us-east-1')

LAMBDA_NAME = 'lee-repositorio-lambda'
S3_BUCKET = 'poc-code-analyzer-2026'

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/analizar', methods=['POST'])
def analizar():
    data = request.json
    repo_url = data.get('repo_url')
    
    if not repo_url:
        return jsonify({'error': 'URL del repositorio requerida'}), 400
    
    # Invocar Lambda
    payload = {
        'body': json.dumps({
            'repo_url': repo_url,
            'sessionId': f'web-{int(time.time())}'
        })
    }
    
    response = lambda_client.invoke(
        FunctionName=LAMBDA_NAME,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload)
    )
    
    result = json.loads(response['Payload'].read())
    body = json.loads(result.get('body', '{}'))
    
    # Si no vienen los nombres de archivos, listar S3 para obtener los más recientes
    if not body.get('asis_document') or not body.get('tobe_document'):
        try:
            # Listar archivos AS-IS
            asis_objects = s3_client.list_objects_v2(
                Bucket=S3_BUCKET,
                Prefix='documentos-generados/asis/',
                MaxKeys=1
            )
            if 'Contents' in asis_objects:
                asis_sorted = sorted(asis_objects['Contents'], key=lambda x: x['LastModified'], reverse=True)
                body['asis_document'] = asis_sorted[0]['Key'].split('/')[-1]
            
            # Listar archivos TO-BE
            tobe_objects = s3_client.list_objects_v2(
                Bucket=S3_BUCKET,
                Prefix='documentos-generados/tobe/',
                MaxKeys=1
            )
            if 'Contents' in tobe_objects:
                tobe_sorted = sorted(tobe_objects['Contents'], key=lambda x: x['LastModified'], reverse=True)
                body['tobe_document'] = tobe_sorted[0]['Key'].split('/')[-1]
        except Exception as e:
            print(f"Error listando S3: {e}")
    
    return jsonify(body)

@app.route('/descargar/<tipo>/<filename>')
def descargar(tipo, filename):
    s3_key = f'documentos-generados/{tipo}/{filename}'
    local_path = f'/tmp/{filename}'
    
    s3_client.download_file(S3_BUCKET, s3_key, local_path)
    return send_file(local_path, as_attachment=True, download_name=filename)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=3000)
