#!/bin/bash

# Solicita o diretório onde os arquivos de inventário estão localizados
read -p "Digite o caminho do diretório onde estão os arquivos de inventário: " dir_inventario

# Função para verificar se um arquivo contém recursos ativos
function verificar_recursos() {
    arquivo=$1
    tem_recursos=false

    # Verifica palavras-chave indicativas de recursos
    palavras_chave=("NAME" "ID" "RUNTIME" "ZONE" "SERVICE" "STATE" "TIER" "STATUS" "gs://")

    # Lê o arquivo linha por linha
    while IFS= read -r linha; do
        # Ignora linhas de separação ou linhas vazias
        if [[ "$linha" =~ ^={5,} ]] || [[ -z "$linha" ]]; then
            continue
        fi

        # Verifica se a linha contém uma das palavras-chave que indicam recursos
        for palavra in "${palavras_chave[@]}"; do
            if [[ "$linha" =~ $palavra ]]; then
                tem_recursos=true
                break 2
            fi
        done
    done < "$arquivo"

    # Se encontrou recursos, exibe o nome do arquivo
    if [ "$tem_recursos" = true ]; then
        echo "$arquivo"
    fi
}

# Percorre todos os arquivos de inventário no diretório fornecido
for arquivo in "$dir_inventario"/*.txt; do
    if [ -f "$arquivo" ]; then
        verificar_recursos "$arquivo"
    else
        echo "Nenhum arquivo de inventário encontrado no diretório $dir_inventario."
        break
    fi
done