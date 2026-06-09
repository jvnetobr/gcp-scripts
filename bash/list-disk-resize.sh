#!/usr/bin/env bash
set -euo pipefail

read -rp "ID do projeto (PROJECT_ID): " PROJECT_ID
read -rp "Nome do disco (DISK_NAME): " DISK_NAME

command -v gcloud >/dev/null || { echo "gcloud não encontrado"; exit 1; }
command -v jq >/dev/null || { echo "jq não encontrado"; exit 1; }
gcloud config set project "$PROJECT_ID" >/dev/null

# -------- Descobrir se é Zonal ou Regional (com fallback beta/alpha) --------
has_cmd(){ "$@" --help >/dev/null 2>&1; }
REGION_DISKS_LIST_CMD=()
if has_cmd gcloud compute region-disks; then
  REGION_DISKS_LIST_CMD=(gcloud compute region-disks list)
elif has_cmd gcloud beta compute region-disks; then
  REGION_DISKS_LIST_CMD=(gcloud beta compute region-disks list)
elif has_cmd gcloud alpha compute region-disks; then
  REGION_DISKS_LIST_CMD=(gcloud alpha compute region-disks list)
fi

ZONAL_MATCHES=$(gcloud compute disks list \
  --filter="name='$DISK_NAME'" \
  --format="csv[no-heading](name,zone,selfLink)" | sed '/^$/d' || true)

REGIONAL_MATCHES=""
if ((${#REGION_DISKS_LIST_CMD[@]})); then
  REGIONAL_MATCHES=$("${REGION_DISKS_LIST_CMD[@]}" \
    --filter="name='$DISK_NAME'" \
    --format="csv[no-heading](name,location,selfLink)" | sed '/^$/d' || true)
fi

choose(){ local a=("$@"); local PS3="Selecione (1-${#a[@]}): "; select o in "${a[@]}"; do [[ -n "$o" ]] && { echo "$o"; break; }; done; }

SCOPE_TYPE=""; LOC=""
if [[ -n "$ZONAL_MATCHES" && -z "$REGIONAL_MATCHES" ]]; then
  if [[ $(printf "%s\n" "$ZONAL_MATCHES" | wc -l) -gt 1 ]]; then
    echo "Discos ZONAIS com esse nome:"; mapfile -t ZLIST <<<"$(printf "%s\n" "$ZONAL_MATCHES")"
    opts=(); for l in "${ZLIST[@]}"; do opts+=("Zonal: $(cut -d, -f1 <<<"$l")  ($(cut -d, -f2 <<<"$l"))"); done
    sel=$(choose "${opts[@]}"); idx=$(printf "%s\n" "${opts[@]}" | nl -ba | grep -nF "$sel" | awk -F: '{print $1}')
    line="${ZLIST[$((idx-1))]}"; LOC=$(cut -d, -f2 <<<"$line")
  else
    LOC=$(cut -d, -f2 <<<"$ZONAL_MATCHES")
  fi; SCOPE_TYPE="zone"
elif [[ -z "$ZONAL_MATCHES" && -n "$REGIONAL_MATCHES" ]]; then
  if [[ $(printf "%s\n" "$REGIONAL_MATCHES" | wc -l) -gt 1 ]]; then
    echo "Discos REGIONAIS com esse nome:"; mapfile -t RLIST <<<"$(printf "%s\n" "$REGIONAL_MATCHES")"
    opts=(); for l in "${RLIST[@]}"; do loc=$(cut -d, -f2 <<<"$l"); [[ -z "$loc" ]] && loc=$(cut -d/ -f7 <<<"$(cut -d, -f3- <<<"$l")"); opts+=("Regional: $(cut -d, -f1 <<<"$l")  ($loc)"); done
    sel=$(choose "${opts[@]}"); idx=$(printf "%s\n" "${opts[@]}" | nl -ba | grep -nF "$sel" | awk -F: '{print $1}')
    line="${RLIST[$((idx-1))]}"; LOC=$(cut -d, -f2 <<<"$line"); [[ -z "$LOC" ]] && LOC=$(cut -d/ -f7 <<<"$(cut -d, -f3- <<<"$line")")
  else
    LOC=$(cut -d, -f2 <<<"$REGIONAL_MATCHES"); [[ -z "$LOC" ]] && LOC=$(cut -d/ -f7 <<<"$(cut -d, -f3- <<<"$REGIONAL_MATCHES")")
  fi; SCOPE_TYPE="region"
elif [[ -n "$ZONAL_MATCHES" && -n "$REGIONAL_MATCHES" ]]; then
  echo "Existe ZONAL e REGIONAL com o mesmo nome. Prefira um:"
  echo "1) Zonal  ($(cut -d, -f2 <<<"$ZONAL_MATCHES"))"
  echo "2) Regional ($(cut -d, -f2 <<<"$REGIONAL_MATCHES"))"
  read -rp "#? " pick
  if [[ "$pick" == "1" ]]; then SCOPE_TYPE="zone"; LOC=$(cut -d, -f2 <<<"$ZONAL_MATCHES"); else SCOPE_TYPE="region"; LOC=$(cut -d, -f2 <<<"$REGIONAL_MATCHES"); fi
else
  echo "Disco '$DISK_NAME' não encontrado em $PROJECT_ID."; exit 1
fi

if [[ "$SCOPE_TYPE" == "zone" ]]; then
  CURRENT_SIZE=$(gcloud compute disks describe "$DISK_NAME" --zone "$LOC" --format="value(sizeGb)" 2>/dev/null || true)
  RESOURCE_TYPE="gce_disk"; METHOD_GROUP="disks"
  # regex aceita com/sem /resize no final
  RESOURCE_RE="projects/$PROJECT_ID/zones/$LOC/disks/$DISK_NAME(/.*)?"
else
  # pode não haver o subcomando region-disks no seu SDK; se faltar, pula o tamanho atual
  if has_cmd gcloud compute region-disks || has_cmd gcloud beta compute region-disks || has_cmd gcloud alpha compute region-disks; then
    (gcloud compute region-disks describe "$DISK_NAME" --region "$LOC" --format="value(sizeGb)" 2>/dev/null || true) && CURRENT_SIZE=$(gcloud compute region-disks describe "$DISK_NAME" --region "$LOC" --format="value(sizeGb)" 2>/dev/null || true) || CURRENT_SIZE=""
  else
    CURRENT_SIZE=""
  fi
  RESOURCE_TYPE="gce_region_disk"; METHOD_GROUP="regionDisks"
  RESOURCE_RE="projects/$PROJECT_ID/regions/$LOC/disks/$DISK_NAME(/.*)?"
fi

# -------- Filtro de logs (regex no resourceName!) --------
read -r -d '' FILTER <<EOF || true
resource.type="$RESOURCE_TYPE"
protoPayload.serviceName="compute.googleapis.com"
protoPayload.resourceName=~"$RESOURCE_RE"
(
  protoPayload.methodName=~"compute\\.(v1\\.)?${METHOD_GROUP}\\.insert" OR
  protoPayload.methodName=~"compute\\.(v1\\.)?${METHOD_GROUP}\\.resize"
)
EOF

TMP_JSON="/tmp/disk_resize_history_${PROJECT_ID}_${DISK_NAME}.json"
OUT_TSV="/tmp/disk_resize_history_${PROJECT_ID}_${DISK_NAME}.tsv"
OUT_CSV="/tmp/disk_resize_history_${PROJECT_ID}_${DISK_NAME}.csv"

# fresh = 400d garante a janela padrão de Admin Activity
gcloud logging read "$FILTER" --format=json --limit=1000 --freshness=400d --order=asc > "$TMP_JSON"

EVENTS=$(jq 'length' "$TMP_JSON")
# ---- Se quiser depurar, descomente:
# jq -r '.[] | [.timestamp, .protoPayload.methodName, .protoPayload.resourceName, .protoPayload.request] | @json' "$TMP_JSON" | head

jq -r '
  def get_size:
    .protoPayload.request.sizeGb //
    .protoPayload.request.disk.sizeGb //
    .protoPayload.request.resource.sizeGb //
    .protoPayload.request.initializeParams.diskSizeGb
    | (if . == null then null else tonumber? end);

  map({
    ts: .timestamp,
    method: .protoPayload.methodName,
    user: (.protoPayload.authenticationInfo.principalEmail // "desconhecido"),
    size: ( . | get_size )
  })
  | sort_by(.ts)
  | (["timestamp","acao","novo_tamanho_GB","expandiu_GB","por_quem"] | @tsv),
    ( range(0; length) as $i
      | .[$i] as $e
      | [
          $e.ts,
          (if ($e.method | test("resize")) then "resize" else "create" end),
          ($e.size // ""),
          (if ($i>0 and ($e.method|test("resize")) and (.[$i-1].size != null) and ($e.size != null))
             then ($e.size - .[$i-1].size)
             else "" end),
          $e.user
        ] | @tsv )
' "$TMP_JSON" | tee "$OUT_TSV" >/dev/null

tr '\t' ',' < "$OUT_TSV" > "$OUT_CSV"

echo
echo "================ RESULTADO ================"
column -t -s$'\t' "$OUT_TSV" || cat "$OUT_TSV"
echo "------------------------------------------"
echo "Projeto:         $PROJECT_ID"
echo "Disco:           $DISK_NAME"
echo "Escopo/Local:    $SCOPE_TYPE / $LOC"
[[ -n "${CURRENT_SIZE:-}" ]] && echo "Tamanho atual:    ${CURRENT_SIZE} GB"
echo "Eventos lidos:   ${EVENTS}"
echo "Arquivos:"
echo "  TSV: $OUT_TSV"
echo "  CSV: $OUT_CSV"
echo "=========================================="

if [[ "$EVENTS" -eq 0 ]]; then
  echo "ATENÇÃO: Nenhum evento encontrado. Motivos comuns:"
  echo " - Sem resize/insert dentro da retenção (≈400 dias) de Admin Activity;"
  echo " - Filtro de projeto/zona/região diferente do disco real;"
  echo " - Audit Logs desativados no passado (raro para Admin Activity)."
  echo "Dica: rode um sanity check:"
  echo "gcloud logging read \"protoPayload.methodName=~'disks\\.resize' AND protoPayload.resourceName: '$DISK_NAME'\" --limit=5 --format='table(timestamp,protoPayload.methodName,protoPayload.resourceName,protoPayload.request.sizeGb)'"
fi