#!/bin/bash

# Solicita o ID do projeto
read -p "Digite o ID do projeto GCP: " PROJECT_ID

# Solicita o nome do arquivo de saída
read -p "Digite o nome do arquivo de saída: " output_file

# Defina o projeto padrão
gcloud config set project $PROJECT_ID

# Inicie o arquivo de saída
echo "Mapeamento de recursos do projeto GCP: $PROJECT_ID" > "$output_file"
echo "Data: $(date)" >> "$output_file"
echo "=====================================" >> "$output_file"

# Função para listar e salvar os recursos de cada serviço
function list_resources() {
    echo "=====================================" >> "$output_file"
    echo "$1" >> "$output_file"
    echo "=====================================" >> "$output_file"
    eval "$2" >> "$output_file"
}

# Compute Engine (Instâncias)
list_resources "Instâncias do Compute Engine:" "gcloud compute instances list --format='table(name, zone, machineType, status)'"

# Cloud Storage (Buckets)
list_resources "Buckets do Cloud Storage:" "gsutil ls"

# Cloud SQL (Bancos de Dados)
list_resources "Instâncias do Cloud SQL:" "gcloud sql instances list --format='table(name, databaseVersion, region, tier)'"

# GKE (Clusters Kubernetes)
list_resources "Clusters GKE (Google Kubernetes Engine):" "gcloud container clusters list --format='table(name, zone, status)'"

# Firestore (Banco de Dados NoSQL)
list_resources "Firestore Databases:" "gcloud firestore databases list --format='table(name, locationId)'"

# BigQuery (Conjuntos de Dados)
list_resources "Conjuntos de dados do BigQuery:" "bq ls --format=prettyjson"

# App Engine (Aplicativos)
list_resources "Aplicativos do App Engine:" "gcloud app services list --format='table(id, split)'" 

# Cloud Functions (Funções Serverless)
list_resources "Cloud Functions:" "gcloud functions list --format='table(name, runtime, status)'"

# Pub/Sub (Tópicos)
list_resources "Tópicos do Pub/Sub:" "gcloud pubsub topics list --format='table(name)'"

# Filas do Cloud Tasks
list_resources "Filas do Cloud Tasks:" "gcloud tasks queues list --format='table(name, state)'"

# Verifica a saída
echo "O mapeamento de recursos foi salvo no arquivo: $output_file"