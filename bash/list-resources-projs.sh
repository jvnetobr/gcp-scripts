#!/bin/bash

# Solicita o nome do arquivo de saída
read -p "Digite o nome do arquivo de saída (será salvo por projeto): " output_file_base

# Função para verificar se a API está ativada
function is_api_enabled() {
    API=$1
    gcloud services list --enabled --format="value(config.name)" | grep -q "$API"
}

# Função para listar e salvar os recursos de cada serviço
function list_resources() {
    echo "=====================================" >> "$output_file"
    echo "$1" >> "$output_file"
    echo "=====================================" >> "$output_file"
    eval "$2" >> "$output_file"
}

# Lista todos os projetos aos quais você tem acesso
PROJECTS=$(gcloud projects list --format="value(projectId)")

# Itera sobre cada projeto
for PROJECT_ID in $PROJECTS; do
    # Define o projeto atual
    gcloud config set project $PROJECT_ID

    # Define o nome do arquivo de saída para o projeto atual
    output_file="${output_file_base}_${PROJECT_ID}.txt"

    # Inicia o arquivo de saída para o projeto
    echo "Mapeamento de recursos do projeto GCP: $PROJECT_ID" > "$output_file"
    echo "Data: $(date)" >> "$output_file"
    echo "=====================================" >> "$output_file"

    # Verifica e lista recursos para cada serviço, apenas se a API estiver ativada

    # Compute Engine (Instâncias)
    if is_api_enabled "compute.googleapis.com"; then
        list_resources "Instâncias do Compute Engine:" "gcloud compute instances list --format='table(name, zone, machineType, status)'"
    fi

    # Cloud Storage (Buckets)
    if is_api_enabled "storage.googleapis.com"; then
        list_resources "Buckets do Cloud Storage:" "gsutil ls"
    fi

    # Cloud SQL (Bancos de Dados)
    if is_api_enabled "sqladmin.googleapis.com"; then
        list_resources "Instâncias do Cloud SQL:" "gcloud sql instances list --format='table(name, databaseVersion, region, tier)'"
    fi

    # GKE (Clusters Kubernetes)
    if is_api_enabled "container.googleapis.com"; then
        list_resources "Clusters GKE (Google Kubernetes Engine):" "gcloud container clusters list --format='table(name, zone, status)'"
    fi

    # Firestore (Banco de Dados NoSQL)
    if is_api_enabled "firestore.googleapis.com"; then
        list_resources "Firestore Databases:" "gcloud firestore databases list --format='table(name, locationId)'"
    fi

    # BigQuery (Conjuntos de Dados)
    if is_api_enabled "bigquery.googleapis.com"; then
        list_resources "Conjuntos de dados do BigQuery:" "bq ls --format=prettyjson"
    fi

    # App Engine (Aplicativos)
    if is_api_enabled "appengine.googleapis.com"; then
        list_resources "Aplicativos do App Engine:" "gcloud app services list --format='table(id, split)'"
    fi

    # Cloud Functions (Funções Serverless)
    if is_api_enabled "cloudfunctions.googleapis.com"; then
        list_resources "Cloud Functions:" "gcloud functions list --format='table(name, runtime, status)'"
    fi

    # Pub/Sub (Tópicos)
    if is_api_enabled "pubsub.googleapis.com"; then
        list_resources "Tópicos do Pub/Sub:" "gcloud pubsub topics list --format='table(name)'"
    fi

    # Filas do Cloud Tasks
    if is_api_enabled "cloudtasks.googleapis.com"; then
        list_resources "Filas do Cloud Tasks:" "gcloud tasks queues list --format='table(name, state)'"
    fi

    # Verifica a saída
    echo "O mapeamento de recursos foi salvo no arquivo: $output_file"
done

echo "Inventário completo para todos os projetos."