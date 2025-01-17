#!/bin/bash

# Defina variáveis para a VM
NOME_VM="vm-monitoring"
ZONE="us-central1-a"  
VPC_NAME="vpc-kedu-prod-monitoring"
SUBNET_NAME="subnet-kedu-prod-monitoring"
MACHINE_TYPE="e2-small"
DISK_SIZE="10GB"
IMAGE_FAMILY="debian-12"
IMAGE_PROJECT="debian-cloud"

# Criação da VM
echo "Criando a VM $NOME_VM na rede $VPC_NAME..."
gcloud compute instances create $NOME_VM \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --subnet=$SUBNET_NAME \
    --network=$VPC_NAME \
    --boot-disk-size=$DISK_SIZE \
    --boot-disk-type=pd-standard \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT \
    --tags=http-server,https-server \
    --description="VM para rodar a stack de monitoramento com Docker"

echo "VM $NOME_VM criada."