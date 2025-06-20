#!/bin/bash

# Solicita o e-mail do usuário antigo
read -p "Digite o e-mail do usuário antigo: " OLD_USER

# Solicita o e-mail do novo usuário
read -p "Digite o e-mail do novo usuário: " NEW_USER

# Solicita o ID do projeto
read -p "Digite o ID do projeto: " PROJECT_ID

# Listar as roles do usuário antigo
ROLES=$(gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format='value(bindings.role)' --filter="bindings.members:$OLD_USER")

# Verifica se foram encontradas roles
if [ -z "$ROLES" ]; then
  echo "Nenhuma role encontrada para o usuário $OLD_USER no projeto $PROJECT_ID."
  exit 1
fi

# Aplicar cada role ao novo usuário
for ROLE in $ROLES; do
  echo "Atribuindo a role $ROLE ao usuário $NEW_USER..."
  gcloud projects add-iam-policy-binding $PROJECT_ID --member="user:$NEW_USER" --role="$ROLE"
done

echo "Todas as roles foram copiadas do usuário $OLD_USER para o usuário $NEW_USER no projeto $PROJECT_ID."