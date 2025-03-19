#!/bin/bash

# Solicita ao usuário que informe o ID do projeto
read -p "Digite o ID do projeto GCP: " PROJECT_ID

# Verifica se o ID do projeto foi fornecido
if [ -z "$PROJECT_ID" ]; then
    echo "Erro: Nenhum ID de projeto informado!"
    exit 1
fi

# Nome do arquivo CSV de saída
OUTPUT_FILE="../usuarios_iam_$PROJECT_ID.csv"

# Cabeçalho do CSV
echo "Usuário,Roles" > "$OUTPUT_FILE"

# Obtém a lista de permissões IAM e formata no estilo "usuário, role1;role2;role3"
gcloud projects get-iam-policy "$PROJECT_ID" --format=json | jq -r '
    .bindings[] | 
    .role as $role | 
    .members[] | 
    select(startswith("user:")) | 
    {user: (split(":")[1]), role: $role}
' | jq -s 'group_by(.user) | 
    map({user: .[0].user, roles: map(.role) | join(";")}) | 
    .[] | "\(.user),\(.roles)"
' >> "$OUTPUT_FILE"

echo "Exportação concluída! Arquivo salvo como: $OUTPUT_FILE"