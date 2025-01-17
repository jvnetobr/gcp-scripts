#!/bin/bash

# Definição das variáveis para nomear a VPC e sub-rede
NOME_EMPRESA="kedu"
AMBIENTE="prod"
VPC_NAME="vpc-$NOME_EMPRESA-$AMBIENTE-monitoring"
SUBNET_NAME="subnet-$NOME_EMPRESA-$AMBIENTE-monitoring"
REGION="us-central1" 
SUBNET_RANGE="10.0.0.0/24"  

# Criação da VPC
echo "Criando a VPC $VPC_NAME..."
gcloud compute networks create $VPC_NAME \
    --subnet-mode=custom \
    --description="VPC para $NOME_EMPRESA em $AMBIENTE, utilizada para o ambiente de monitoramento"

# Criação da sub-rede na região especificada
echo "Criando a sub-rede $SUBNET_NAME..."
gcloud compute networks subnets create $SUBNET_NAME \
    --network=$VPC_NAME \
    --region=$REGION \
    --range=$SUBNET_RANGE \
    --description="Sub-rede para $NOME_EMPRESA em $AMBIENTE, utilizada para o ambiente de monitoramento"

# Regra de firewall para liberar a porta 9001 (Exposição de métricas dos nós)
#echo "Criando a regra de firewall para a porta 9001 (Exposição de métricas)..."
#gcloud compute firewall-rules create allow-metrics-port-9001 \
#    --network $VPC_NAME \
#    --allow tcp:9001 \
#    --source-ranges 0.0.0.0/0 \
#    --description="Permitir acesso à porta 9001 para exposição de métricas dos nós no ambiente de monitoramento"

gcloud compute firewall-rules create monitoring-allow-grafana \
    --network $VPC_NAME \
    --allow tcp:3000 \
    --source-ranges 0.0.0.0/0 \
    --description "Permitir acesso ao Grafana"

# Cria regra de firewall para permitir acesso à porta do Prometheus
gcloud compute firewall-rules create monitoring-allow-prometheus \
    --network $VPC_NAME \
    --allow tcp:9090 \
    --source-ranges 0.0.0.0/0 \
    --description "Permitir acesso ao Prometheus"

# Regra de firewall para liberar a porta 80 (HTTP)
echo "Criando a regra de firewall para a porta 80 (HTTP)..."
gcloud compute firewall-rules create monitoring-allow-http \
    --network $VPC_NAME \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --description="Permitir acesso à porta HTTP (80) no ambiente de monitoramento"

# Regra de firewall para liberar a porta 443 (HTTPS)
echo "Criando a regra de firewall para a porta 443 (HTTPS)..."
gcloud compute firewall-rules create monitoring-allow-https \
    --network $VPC_NAME \
    --allow tcp:443 \
    --source-ranges 0.0.0.0/0 \
    --description="Permitir acesso à porta HTTPS (443) no ambiente de monitoramento"

echo "VPC, sub-rede e regras de firewall criadas com sucesso!"