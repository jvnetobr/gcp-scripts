#!/bin/bash

# Script para mapear recursos de um projeto GCP

set -euo pipefail

# Solicita o ID do projeto GCP
read -rp "Digite o ID do projeto GCP: " PROJECT_ID

# Define o nome do arquivo de saída automaticamente com base no projeto e data/hora
output_file="mapeamento_recursos_${PROJECT_ID}_$(date +'%Y%m%d_%H%M%S').txt"

# Define o projeto padrão no gcloud
gcloud config set project "$PROJECT_ID" --quiet

# Função para checar se uma API está habilitada
function check_api_enabled() {
    local SERVICE="$1"
    gcloud services list --enabled --format="value(config.name)" | grep -qw "$SERVICE"
}

# Função para listar e salvar recursos de cada serviço
function list_resources() {
    local HEADER="$1"
    local CMD="$2"
    local SERVICE_API="$3"

    echo "=====================================" >> "$output_file"
    echo "$HEADER" >> "$output_file"
    echo "=====================================" >> "$output_file"
    if check_api_enabled "$SERVICE_API"; then
        # Executa o comando e trata caso não haja recursos
        if ! eval "$CMD" | tee -a "$output_file" | grep -qve '^$'; then
            echo "Nenhum recurso encontrado para $HEADER" >> "$output_file"
        fi
    else
        echo "API '$SERVICE_API' não está habilitada para este projeto. Nenhum recurso listado." >> "$output_file"
    fi
    echo "" >> "$output_file"
}

# Inicia o arquivo de saída
{
    echo "Mapeamento de recursos do projeto GCP: $PROJECT_ID"
    echo "Data: $(date)"
    echo "====================================="
} > "$output_file"

# Mapear recursos dos principais serviços GCP

# Compute Engine (Instâncias)
list_resources "Instâncias do Compute Engine:" \
    "gcloud compute instances list --format='table(name, zone, machineType, status)'" \
    "compute.googleapis.com"

# Cloud Storage (Buckets)
list_resources "Buckets do Cloud Storage:" \
    "gsutil ls" \
    "storage.googleapis.com"

# Cloud SQL (Instâncias)
list_resources "Instâncias do Cloud SQL:" \
    "gcloud sql instances list --format='table(name, databaseVersion, region, tier)'" \
    "sqladmin.googleapis.com"

# Google Kubernetes Engine (Clusters)
list_resources "Clusters GKE (Google Kubernetes Engine):" \
    "gcloud container clusters list --format='table(name, location, status)'" \
    "container.googleapis.com"

# Firestore (Banco de Dados NoSQL)
list_resources "Firestore Databases:" \
    "gcloud firestore databases list --format='table(name, locationId)'" \
    "firestore.googleapis.com"

# BigQuery (Conjuntos de Dados)
list_resources "Conjuntos de dados do BigQuery:" \
    "bq ls --format=prettyjson" \
    "bigquery.googleapis.com"

# App Engine (Aplicativos)
list_resources "Aplicativos do App Engine:" \
    "gcloud app services list --format='table(id, split)'" \
    "appengine.googleapis.com"

# Cloud Functions (Funções Serverless)
list_resources "Cloud Functions:" \
    "gcloud functions list --format='table(name, runtime, status)'" \
    "cloudfunctions.googleapis.com"

# Pub/Sub (Tópicos)
list_resources "Tópicos do Pub/Sub:" \
    "gcloud pubsub topics list --format='table(name)'" \
    "pubsub.googleapis.com"

# Filas do Cloud Tasks
list_resources "Filas do Cloud Tasks:" \
    "gcloud tasks queues list --format='table(name, state)'" \
    "cloudtasks.googleapis.com"

echo "O mapeamento de recursos foi salvo no arquivo: $output_file"