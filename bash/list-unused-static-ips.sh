#!/usr/bin/env bash
# list-unused-static-ips.sh
# Lista IPs públicos estáticos (EXTERNAL, status=RESERVED) sem uso na GCP.
# Cruza com forwarding-rules (globais e regionais). Opcionalmente busca referência em Cloud DNS.
#
# Uso:
#   ./list-unused-static-ips.sh                 # todos os projetos (gcloud projects list)
#   ./list-unused-static-ips.sh -p projA,projB  # somente projetos informados
#   ./list-unused-static-ips.sh -p projA --dns  # inclui verificação de referência no Cloud DNS
#
# Saída: CSV em stdout + tabela amigável (stderr). Você pode redirecionar o CSV.

set -euo pipefail

PROJECTS=""
CHECK_DNS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--projects)
      PROJECTS="${2:-}"
      shift 2
      ;;
    --dns|--include-dns)
      CHECK_DNS=true
      shift
      ;;
    -h|--help)
      sed -n '1,100p' "$0" | sed -n '1,40p'
      exit 0
      ;;
    *)
      echo "Parâmetro não reconhecido: $1" >&2
      exit 1
      ;;
  esac
done

# Monta lista de projetos
if [[ -z "$PROJECTS" ]]; then
  mapfile -t PROJS < <(gcloud projects list --format="value(projectId)")
else
  IFS=',' read -r -a PROJS <<< "$PROJECTS"
fi

# Cabeçalho CSV
echo "project,scope,region,name,address,status,addressType,purpose,has_users,referenced_by_fwrule,referenced_in_dns,motive"

print_row() {
  local project="$1" scope="$2" region="$3" name="$4" address="$5" status="$6" atype="$7" purpose="$8" has_users="$9" ref_fw="${10}" ref_dns="${11}" motive="${12}"
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,"%s"\n' \
    "$project" "$scope" "$region" "$name" "$address" "$status" "$atype" "${purpose:-}" "$has_users" "$ref_fw" "$ref_dns" "$motive"
}

for P in "${PROJS[@]}"; do
  echo ">> Varredura do projeto: $P" >&2

  # Forwarding rules (globais e regionais) para cruzamento por IP
  FWR_JSON="$(gcloud compute forwarding-rules list --project="$P" --format=json || echo '[]')"
  # Conjunto de IPs presentes em forwarding rules
  mapfile -t FW_IPS < <(jq -r '.[].IPAddress' <<<"$FWR_JSON" | sort -u)

  # Endereços (globais e regionais)
  ADDR_JSON="$(gcloud compute addresses list --project="$P" --format=json || echo '[]')"

  # Filtra candidatos: EXTERNAL + RESERVED
  jq -c '.[] | select(.addressType=="EXTERNAL" and .status=="RESERVED")' <<<"$ADDR_JSON" | while read -r A; do
    name=$(jq -r '.name' <<<"$A")
    address=$(jq -r '.address' <<<"$A")
    status=$(jq -r '.status' <<<"$A")
    atype=$(jq -r '.addressType' <<<"$A")
    purpose=$(jq -r '.purpose // empty' <<<"$A")
    users_count=$(jq -r '.users | length' <<<"$A")
    region_url=$(jq -r '.region // empty' <<<"$A")
    scope="global"; region=""
    if [[ -n "$region_url" ]]; then
      scope="regional"
      region="${region_url##*/}"
    fi

    # Ignora propósitos não usuais (ex.: VPC_PEERING, PRIVATE_SERVICE_CONNECT, SHARED_LOADBALANCER_VIP, etc.)
    # Se quiser listar mesmo assim, comente o bloco abaixo.
    if [[ -n "$purpose" && "$purpose" != "GCE_ENDPOINT" ]]; then
      motive="Ignorado: purpose=$purpose"
      print_row "$P" "$scope" "$region" "$name" "$address" "$status" "$atype" "$purpose" "$([[ $users_count -gt 0 ]] && echo yes || echo no)" "n/a" "n/a" "$motive"
      continue
    fi

    # Checa se há users (vínculo direto através do campo users)
    has_users="no"
    if [[ $users_count -gt 0 ]]; then
      has_users="yes"
    fi

    # Checa vínculo indireto via Forwarding Rules (por IP)
    ref_fw="no"
    if printf '%s\n' "${FW_IPS[@]}" | grep -Fxq "$address"; then
      ref_fw="yes"
    fi

    # Checagem opcional de referência em Cloud DNS (A/AAAA contendo o IP)
    ref_dns="no"
    if $CHECK_DNS; then
      # Lista todos os RRsets e procura o IP nas rrdatas (A/AAAA e até TXT, se alguém anotou)
      ZONES_JSON="$(gcloud dns managed-zones list --project="$P" --format=json || echo '[]')"
      if [[ "$(jq 'length' <<<"$ZONES_JSON")" -gt 0 ]]; then
        # Para cada zona, consulta RRsets
        while read -r ZNAME; do
          RR_JSON="$(gcloud dns record-sets list --project="$P" --zone="$ZNAME" --format=json || echo '[]')"
          hit=$(jq --arg ip "$address" '[.[] | select((.type=="A" or .type=="AAAA" or .type=="TXT") and (.rrdatas[]? | contains($ip)))) | length' <<<"$RR_JSON")
          if [[ "$hit" -gt 0 ]]; then
            ref_dns="yes"
            break
          fi
        done < <(jq -r '.[].name' <<<"$ZONES_JSON")
      fi
    fi

    # Decide se é "sem uso"
    if [[ "$has_users" == "no" && "$ref_fw" == "no" ]]; then
      motive="Sem vínculos (users vazio; não aparece em forwarding-rules)$($CHECK_DNS && [[ $ref_dns == yes ]] && echo '; POSSÍVEL referência em DNS' || true)"
      print_row "$P" "$scope" "$region" "$name" "$address" "$status" "$atype" "$purpose" "$has_users" "$ref_fw" "$ref_dns" "$motive"
    else
      motive="Em uso: $([[ $has_users == yes ]] && echo 'users>0; ' || true)$([[ $ref_fw == yes ]] && echo 'aparece em forwarding-rules; ' || true)"
      print_row "$P" "$scope" "$region" "$name" "$address" "$status" "$atype" "$purpose" "$has_users" "$ref_fw" "$ref_dns" "$motive"
    fi
  done

done | tee ./unused_static_ips_raw.csv | {
  # Além do CSV, imprime uma tabelinha amigável no stderr com os realmente "sem uso"
  awk -F',' 'NR==1{next} $9=="no" && $10=="no" {printf "%-24s %-8s %-12s %-32s %-15s %-8s %s\n",$1,$2,$3,$4,$5,$6,$12}' \
    >./unused_static_ips_table.txt
  {
    echo ""
    echo "Resumo (candidatos a exclusão):"
    printf "%-24s %-8s %-12s %-32s %-15s %-8s %s\n" "project" "scope" "region" "name" "address" "status" "motive"
    cat ./unused_static_ips_table.txt
    echo ""
    echo "CSV completo salvo em ./unused_static_ips_raw.csv"
  } >&2
}