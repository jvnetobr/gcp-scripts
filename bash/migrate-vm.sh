#!/bin/bash

# Função para exibir a ajuda
function show_help() {
    echo "Uso: ./migrate_vm_gcp.sh -s SOURCE_PROJECT_ID -d DESTINATION_PROJECT_ID -i INSTANCE_NAME -z ZONE -k DISK_NAME -n SNAPSHOT_NAME -b BUCKET_NAME -m IMAGE_NAME -v NEW_INSTANCE_NAME"
    echo "  -s SOURCE_PROJECT_ID    ID do projeto de origem"
    echo "  -d DESTINATION_PROJECT_ID ID do projeto de destino"
    echo "  -i INSTANCE_NAME        Nome da instância (ex: web-server)"
    echo "  -z ZONE                 Zona da instância (ex: us-central1-a)"
    echo "  -k DISK_NAME            Nome do disco (ex: web-server-disk)"
    echo "  -n SNAPSHOT_NAME        Nome do snapshot (ex: web-server-snapshot)"
    echo "  -b BUCKET_NAME          Nome do bucket do Cloud Storage (ex: meu-bucket-migracao)"
    echo "  -m IMAGE_NAME           Nome da imagem (ex: web-server-image)"
    echo "  -v NEW_INSTANCE_NAME    Nome da nova instância (ex: novo-web-server)"
}

# Parse dos parâmetros de linha de comando
while getopts "s:d:i:z:k:n:b:m:v:h" opt; do
    case ${opt} in
        s )
            SOURCE_PROJECT_ID=$OPTARG
            ;;
        d )
            DESTINATION_PROJECT_ID=$OPTARG
            ;;
        i )
            INSTANCE_NAME=$OPTARG
            ;;
        z )
            ZONE=$OPTARG
            ;;
        k )
            DISK_NAME=$OPTARG
            ;;
        n )
            SNAPSHOT_NAME=$OPTARG
            ;;
        b )
            BUCKET_NAME=$OPTARG
            ;;
        m )
            IMAGE_NAME=$OPTARG
            ;;
        v )
            NEW_INSTANCE_NAME=$OPTARG
            ;;
        h )
            show_help
            exit 0
            ;;
        \? )
            echo "Opção inválida: $OPTARG" 1>&2
            show_help
            exit 1
            ;;
        : )
            echo "Opção requer um argumento: $OPTARG" 1>&2
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

# Verificar se todas as variáveis necessárias foram fornecidas
if [ -z "${SOURCE_PROJECT_ID}" ] || [ -z "${DESTINATION_PROJECT_ID}" ] || [ -z "${INSTANCE_NAME}" ] || [ -z "${ZONE}" ] || [ -z "${DISK_NAME}" ] || [ -z "${SNAPSHOT_NAME}" ] || [ -z "${BUCKET_NAME}" ] || [ -z "${IMAGE_NAME}" ] || [ -z "${NEW_INSTANCE_NAME}" ]; then
    echo "Todos os parâmetros são obrigatórios." 1>&2
    show_help
    exit 1
fi

# Passo 1: Preparar a VM para Exportação
gcloud config set project $SOURCE_PROJECT_ID
gcloud compute instances stop $INSTANCE_NAME --zone $ZONE

# Verificar se o snapshot já existe e excluir se necessário
if gcloud compute snapshots describe $SNAPSHOT_NAME --project $SOURCE_PROJECT_ID > /dev/null 2>&1; then
    echo "Snapshot $SNAPSHOT_NAME já existe. Excluindo snapshot existente..."
    gcloud compute snapshots delete $SNAPSHOT_NAME --quiet --project $SOURCE_PROJECT_ID
fi

# Tentar criar o snapshot novamente se falhar
for i in {1..5}; do
    gcloud compute disks snapshot $DISK_NAME --snapshot-names $SNAPSHOT_NAME --zone $ZONE && break
    echo "Tentando novamente em 30 segundos..."
    sleep 30
done

# Verificar se o snapshot foi criado com sucesso
if ! gcloud compute snapshots describe $SNAPSHOT_NAME --project $SOURCE_PROJECT_ID > /dev/null 2>&1; then
    echo "Erro: Snapshot $SNAPSHOT_NAME não foi criado com sucesso."
    exit 1
fi

# Passo 2: Criar uma imagem a partir do snapshot
gcloud compute images create $IMAGE_NAME --source-snapshot $SNAPSHOT_NAME

# Verificar se a imagem foi criada com sucesso
if ! gcloud compute images describe $IMAGE_NAME --project $SOURCE_PROJECT_ID > /dev/null 2>&1; then
    echo "Erro: Imagem $IMAGE_NAME não foi criada com sucesso."
    exit 1
fi

# Passo 3: Verificar se o Bucket Existe e Criar se Necessário
if gsutil ls -b gs://$BUCKET_NAME > /dev/null 2>&1; then
    echo "Bucket gs://$BUCKET_NAME já existe."
else
    echo "Bucket gs://$BUCKET_NAME não existe. Criando..."
    gsutil mb -p $SOURCE_PROJECT_ID gs://$BUCKET_NAME/
fi

# Configurar Permissões
gsutil iam ch serviceAccount:$DESTINATION_PROJECT_ID@cloudbuild.gserviceaccount.com:objectViewer gs://$BUCKET_NAME

# Passo 4: Exportar a Imagem para um Arquivo
gcloud compute images export --destination-uri gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz --image $IMAGE_NAME

# Verificar se o arquivo foi exportado com sucesso
if ! gsutil -q stat gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz; then
    echo "Erro: Arquivo gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz não encontrado. Certifique-se de que a exportação foi bem-sucedida."
    exit 1
fi

# Passo 5: Importar o Arquivo no Projeto de Destino
gcloud config set project $DESTINATION_PROJECT_ID
gsutil cp gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz ./

# Criar a imagem a partir do arquivo exportado
gcloud compute images create $IMAGE_NAME --source-uri gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz

# Verificar se a imagem foi criada com sucesso
if ! gcloud compute images describe $IMAGE_NAME --project $DESTINATION_PROJECT_ID > /dev/null 2>&1; then
    echo "Erro: Imagem $IMAGE_NAME não foi criada com sucesso no projeto de destino."
    exit 1
fi

# Passo 6: Criar uma Nova VM com a Imagem Importada
gcloud compute instances create $NEW_INSTANCE_NAME --image $IMAGE_NAME --zone $ZONE --project $DESTINATION_PROJECT_ID

# Passo 7: Limpeza
# (Opcional) Excluir o snapshot e o arquivo de imagem do Cloud Storage
gcloud compute snapshots delete $SNAPSHOT_NAME --quiet --project $SOURCE_PROJECT_ID
gsutil rm gs://$BUCKET_NAME/$IMAGE_NAME.tar.gz
rm $IMAGE_NAME.tar.gz

echo "Migração completa!"