#!/bin/bash

# Solicita o caminho do arquivo que contém os caminhos dos arquivos com recursos
read -p "Digite o caminho do arquivo que contém os caminhos dos arquivos com recursos: " arquivo_com_recursos

# Solicita o diretório que contém todos os arquivos (com e sem recursos)
read -p "Digite o caminho do diretório que contém todos os arquivos: " dir_todos_arquivos

# Solicita o diretório de destino para copiar os arquivos com recursos
read -p "Digite o caminho do diretório de destino para os arquivos com recursos: " dir_destino

# Cria o diretório de destino, caso não exista
mkdir -p "$dir_destino"

# Verifica se o arquivo com os caminhos dos arquivos com recursos existe
if [ ! -f "$arquivo_com_recursos" ]; then
    echo "Arquivo contendo os caminhos dos arquivos com recursos não encontrado!"
    exit 1
fi

# Lê o arquivo que contém os caminhos dos arquivos e copia cada arquivo para o diretório de destino
while IFS= read -r caminho_arquivo; do
    nome_arquivo=$(basename "$caminho_arquivo")  # Obtém o nome do arquivo
    if [ -f "$dir_todos_arquivos/$nome_arquivo" ]; then
        cp "$dir_todos_arquivos/$nome_arquivo" "$dir_destino/"
        echo "Arquivo $nome_arquivo copiado para $dir_destino"
    else
        echo "Arquivo $nome_arquivo não encontrado em $dir_todos_arquivos"
    fi
done < "$arquivo_com_recursos"

echo "Cópia de arquivos concluída."