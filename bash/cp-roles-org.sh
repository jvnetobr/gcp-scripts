#!/bin/bash

ORGANIZATION_ID="264802158261"
USER_ORIGEM="gcp_operations@safetec.com.br"
USER_DESTINO="josevieira@gws.kedu.com.br"

echo "Listando roles da conta de origem..."
ROLES=$(gcloud organizations get-iam-policy $ORGANIZATION_ID --flatten="bindings[].members" --format="table(bindings.role, bindings.members)" | grep "$USER_ORIGEM" | awk '{print $1}')

echo "Copiando roles para $USER_DESTINO..."
for ROLE in $ROLES; do
    echo "Adicionando $ROLE..."
    gcloud organizations add-iam-policy-binding $ORGANIZATION_ID \
        --member="user:$USER_DESTINO" \
        --role="$ROLE"
done

echo "Processo concluído!"