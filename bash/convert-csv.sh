#!/bin/bash

# Função para converter um arquivo de inventário de recursos para CSV
function convert_to_csv() {
    input_file=$1
    output_file=$2

    echo "Convertendo $input_file para $output_file..."

    # Inicializa o arquivo CSV com cabeçalhos
    echo "Recurso,Nome,Detalhes" > "$output_file"

    # Variável para armazenar o nome do recurso atual
    current_resource=""
    capture_data=false
    table_headers=""

    # Lê o arquivo linha por linha
    while IFS= read -r line
    do
        # Verifica se a linha é um cabeçalho de recurso (exemplo: Instâncias do Compute Engine:)
        if [[ $line == *":" && $line != *"="* ]]; then
            current_resource=$(echo "$line" | sed 's/:$//')
            capture_data=false  # Para evitar capturar linhas que não sejam de dados
            table_headers=""  # Reinicia os cabeçalhos da tabela
        # Verifica se a linha contém "===" indicando a separação de seções
        elif [[ $line == *"==="* ]]; then
            capture_data=true
        # Verifica se a linha contém dados (não está vazia, nem é separador) e se deve capturar dados
        elif [[ $line != "" && $capture_data == true ]]; then
            if [[ $line == gs://* ]]; then
                # Se a linha for um bucket de Cloud Storage
                echo "$current_resource,$line," >> "$output_file"
            elif [[ $line == NAME* ]]; then
                # Se a linha for um cabeçalho de tabela (ex: Compute Engine Instances)
                table_headers=$line
            elif [[ -n $table_headers ]]; then
                # Se a linha for dados de tabela, incluindo Compute Engine
                echo "$current_resource,$line" >> "$output_file"
            fi
        fi
    done < "$input_file"

    echo "Conversão concluída para $output_file."
}

# Diretório que contém os arquivos de inventário
input_dir="arquivos_tratados"

# Diretório para salvar os arquivos CSV
output_dir="csv_inventarios"

# Cria o diretório de saída, se não existir
mkdir -p "$output_dir"

# Itera sobre todos os arquivos de inventário
for inventory_file in "$input_dir"/*.txt; do
    # Extrai o nome do arquivo sem a extensão
    base_name=$(basename "$inventory_file" .txt)

    # Define o nome do arquivo de saída CSV
    output_csv="$output_dir/${base_name}.csv"

    # Chama a função para converter o arquivo
    convert_to_csv "$inventory_file" "$output_csv"
done

echo "Conversão completa de todos os arquivos de inventário."