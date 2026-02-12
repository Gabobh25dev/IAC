#!/bin/bash

# ===================================================
# Script de escaneo con Checkov
# ===================================================
# Este script ejecuta Checkov para validar la
# infraestructura Terraform contra best practices
# de seguridad y compliance.

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$SCRIPT_DIR"

echo "=========================================="
echo "Iniciando escaneo de seguridad con Checkov"
echo "=========================================="
echo ""

# Verificar que Checkov esté instalado
if ! command -v checkov &> /dev/null; then
    echo "❌ Checkov no está instalado."
    echo "Instalarlo con: pip install checkov"
    exit 1
fi

echo "✓ Checkov encontrado"
echo "Versión: $(checkov --version)"
echo ""

# ===================================================
# Escanear archivos Terraform
# ===================================================

echo "📁 Escaneando archivos Terraform en: $PROJECT_DIR"
echo ""

# Escaneo estándar: mostrar todos los fallos
checkov -d "$PROJECT_DIR" \
    --framework terraform \
    --quiet \
    --output cli \
    --check CKV_AWS_1,CKV_AWS_2,CKV_AWS_3

CHECKOV_EXIT_CODE=$?

echo ""
echo "=========================================="

if [ $CHECKOV_EXIT_CODE -eq 0 ]; then
    echo "✅ Checkov validación EXITOSA"
else
    echo "⚠️  Checkov encontró problemas (código: $CHECKOV_EXIT_CODE)"
fi

echo "=========================================="
echo ""

# ===================================================
# Escaneos adicionales (comentados - descomenta según sea necesario)
# ===================================================

# Escaneo específico de AWS
# echo "🔍 Escaneo específico de AWS..."
# checkov -d "$PROJECT_DIR" --framework terraform --check CKV_AWS_\* --quiet

# Escaneo de IAM
# echo "🔐 Escaneo de IAM..."
# checkov -d "$PROJECT_DIR" --framework terraform --check CKV_AWS_40,CKV_AWS_63

# Escaneo de seguridad de redes
# echo "🌐 Escaneo de seguridad de redes..."
# checkov -d "$PROJECT_DIR" --framework terraform --check CKV_AWS_24,CKV_AWS_25

# Generar reporte en JSON
# echo ""
# echo "📊 Generando reporte JSON..."
# checkov -d "$PROJECT_DIR" \
#     --framework terraform \
#     --output json \
#     --output-file-path checkov_report.json

# if [ -f "checkov_report.json" ]; then
#     echo "✓ Reporte guardado en: checkov_report.json"
# fi

exit $CHECKOV_EXIT_CODE
