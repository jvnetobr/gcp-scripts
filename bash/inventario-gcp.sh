#!/bin/bash

OUTPUT_FILE="gcp-inventory-$(date +%Y%m%d).txt"
PROJETOS=(
  "scio-internal"
  "scio-development"
  "kedu-core"
  "ialves"
  "iamilton"
  "ticket-manager-ti-ai"
  "kedu-wifi-captiveportal"
  "ai-agent-aux-financeiro"
)

echo "Iniciando inventário GCP — $(date)" | tee $OUTPUT_FILE
echo "========================================" | tee -a $OUTPUT_FILE

for PROJETO in "${PROJETOS[@]}"; do
  echo "" | tee -a $OUTPUT_FILE
  echo "==============================" | tee -a $OUTPUT_FILE
  echo "PROJETO: $PROJETO" | tee -a $OUTPUT_FILE
  echo "==============================" | tee -a $OUTPUT_FILE

  # VMs Compute Engine
  echo "--- VMs (Compute Engine) ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud compute instances list \
    --project=$PROJETO \
    --format="table(name,status,zone,machineType.basename())" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhuma ou sem acesso" | tee -a $OUTPUT_FILE

  # Cloud SQL
  echo "--- Cloud SQL ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud sql instances list \
    --project=$PROJETO \
    --format="table(name,databaseVersion,state,region)" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhum ou sem acesso" | tee -a $OUTPUT_FILE

  # Buckets GCS
  echo "--- Buckets GCS ---" | tee -a $OUTPUT_FILE
  timeout 15 gsutil ls -p $PROJETO \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhum ou sem acesso" | tee -a $OUTPUT_FILE

  # GKE Clusters
  echo "--- GKE Clusters ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud container clusters list \
    --project=$PROJETO \
    --format="table(name,status,currentNodeCount,location)" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhum ou sem acesso" | tee -a $OUTPUT_FILE

  # Cloud Run
  echo "--- Cloud Run ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud run services list \
    --project=$PROJETO \
    --platform=managed \
    --format="table(metadata.name,status.conditions[0].type,metadata.namespace)" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhum ou sem acesso" | tee -a $OUTPUT_FILE

  # Cloud Functions
  echo "--- Cloud Functions ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud functions list \
    --project=$PROJETO \
    --format="table(name,status,region)" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhuma ou sem acesso" | tee -a $OUTPUT_FILE

  # App Engine
  echo "--- App Engine ---" | tee -a $OUTPUT_FILE
  timeout 15 gcloud app services list \
    --project=$PROJETO \
    --format="table(id,numVersions)" \
    2>/dev/null | tee -a $OUTPUT_FILE || echo "nenhum ou sem acesso" | tee -a $OUTPUT_FILE

done

echo "" | tee -a $OUTPUT_FILE
echo "========================================" | tee -a $OUTPUT_FILE
echo "Inventário concluído — $(date)" | tee -a $OUTPUT_FILE
echo "Arquivo salvo em: $OUTPUT_FILE"