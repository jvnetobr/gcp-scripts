#!/bin/bash

# Solicita o ID do projeto ao usuário
read -p "Digite o ID do projeto GCP: " PROJECT_ID

# Verifica se o jq está instalado
if ! command -v jq &>/dev/null; then
    echo "O utilitário 'jq' é necessário, mas não está instalado. Instale usando: sudo apt-get install jq"
    exit 1
fi

# Define nome do arquivo de destino
CSV_FILE="iam_bindings_${PROJECT_ID}.csv"

echo "Extraindo IAM bindings do projeto: $PROJECT_ID"

# Exporta os bindings IAM e converte para CSV
gcloud projects get-iam-policy "$PROJECT_ID" \
    --format=json | \
jq -r '
  ["role","member"],
  (.bindings[] | .role as $role | .members[]? | [$role, .])
  | @csv
' > "$CSV_FILE"

if [ $? -eq 0 ]; then
    echo "Exportação concluída com sucesso: $CSV_FILE"
else
    echo "Falha ao exportar as permissões IAM."
    exit 1
fi