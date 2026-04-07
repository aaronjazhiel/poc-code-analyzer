#!/bin/bash

echo "🚀 Iniciando Analizador de Código..."
echo ""

# Instalar dependencias si no existen
if [ ! -d "venv" ]; then
    echo "📦 Creando entorno virtual..."
    python3 -m venv venv
fi

echo "📦 Activando entorno virtual..."
source venv/bin/activate

echo "📦 Instalando dependencias..."
pip install -q -r requirements.txt

echo ""
echo "✅ Servidor listo!"
echo "🌐 Abre tu navegador en: http://localhost:3000"
echo ""

python3 app.py
