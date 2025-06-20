#!/bin/bash
ORG_ORIG=264802158261
ORG_DEST=943914855050
EMAIL="josevieira@kedu.com.br"

gcloud organizations get-iam-policy $ORG_ORIG \
  --flatten="bindings[].members" \
  --format='value(bindings.role)' \
  --filter="bindings.members:user:$EMAIL" | sort | uniq | while read ROLE; do
    echo "Atribuindo role $ROLE ao usuário $EMAIL na organização $ORG_DEST"
    gcloud organizations add-iam-policy-binding $ORG_DEST \
      --member="user:$EMAIL" --role="$ROLE" --quiet
done