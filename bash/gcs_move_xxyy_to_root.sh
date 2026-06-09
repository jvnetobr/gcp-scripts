#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Uso:
  ./gcs_move_xxyy_to_root.sh [--dry-run] [--prefix XX]

  --dry-run     Não altera nada; só mostra o que faria
  --prefix XX   Processa apenas o 1º nível (xx) informado (ex.: 00, 3e, 7g)

Exemplos:
  ./gcs_move_xxyy_to_root.sh --dry-run
  ./gcs_move_xxyy_to_root.sh --prefix 00 --dry-run
  ./gcs_move_xxyy_to_root.sh --prefix 3e
EOF
}

DRY_RUN="false"
ONLY_XX=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN="true"; shift ;;
    --prefix)  ONLY_XX="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Argumento inválido: $1"; usage; exit 1 ;;
  esac
done

read -r -p "Informe o PROJECT (ex: scio-internal): " PROJECT
read -r -p "Informe o BUCKET (sem gs://): " BUCKET

gcloud config set project "$PROJECT" >/dev/null

LOG="gcs_move_xxyy_to_root_$(date +%F_%H%M%S).log"
echo "Project: $PROJECT" | tee -a "$LOG"
echo "Bucket:  $BUCKET"  | tee -a "$LOG"
echo "DryRun:  $DRY_RUN" | tee -a "$LOG"
echo "OnlyXX:  ${ONLY_XX:-<vazio>}" | tee -a "$LOG"

echo "== Bucket metadata ==" | tee -a "$LOG"
gsutil ls -Lb "gs://$BUCKET" | tee -a "$LOG"

# Lista somente objetos no padrão: gs://bucket/xx/yy/key  (xx e yy com 2 chars; key sem '/')
# Observação: o wildcard do gsutil NÃO casa '/', então "*/*/*" pega exatamente 2 níveis + arquivo.
LIST="candidates_$(date +%F_%H%M%S).txt"

if [[ -n "$ONLY_XX" ]]; then
  gsutil ls "gs://$BUCKET/$ONLY_XX/*/*" 2>/dev/null | grep -vE "/$" > "$LIST" || true
else
  gsutil ls "gs://$BUCKET/*/*/*" 2>/dev/null | grep -vE "/$" > "$LIST" || true
fi

echo "Candidatos: $(wc -l < "$LIST") (arquivo: $LIST)" | tee -a "$LOG"

# Função: extrai md5 do gsutil stat (base64)
get_md5() {
  gsutil stat "$1" 2>/dev/null | awk -F': ' '/Hash \(md5\):/{print $2; exit}'
}

moved=0
skipped=0
mismatch=0
dedup_deleted=0
conflict_renamed=0

while IFS= read -r SRC; do
  # SRC exemplo: gs://bucket/xx/yy/key
  REL="${SRC#gs://$BUCKET/}"

  IFS='/' read -r XX YY KEY REST <<< "$REL"

  # Garante exatamente 3 componentes (xx/yy/key)
  if [[ -n "${REST:-}" || -z "${XX:-}" || -z "${YY:-}" || -z "${KEY:-}" ]]; then
    echo "SKIP (não é xx/yy/key): $SRC" | tee -a "$LOG"
    ((skipped++)) || true
    continue
  fi

  # Valida se xx/yy batem com os 4 primeiros chars da KEY (2+2)
  EXP_XX="${KEY:0:2}"
  EXP_YY="${KEY:2:2}"

  if [[ "$XX" != "$EXP_XX" || "$YY" != "$EXP_YY" ]]; then
    echo "MISMATCH xx/yy (orig=$XX/$YY exp=$EXP_XX/$EXP_YY) => $SRC" | tee -a "$LOG"
    ((mismatch++)) || true
    continue
  fi

  DST="gs://$BUCKET/$KEY"

  # Se destino não existe, move
  if ! gsutil -q stat "$DST" >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRYRUN MOVE: $SRC -> $DST" | tee -a "$LOG"
    else
      gsutil mv "$SRC" "$DST" >>"$LOG" 2>&1
      echo "MOVED: $SRC -> $DST" | tee -a "$LOG"
    fi
    ((moved++)) || true
    continue
  fi

  # Destino já existe: compara hash (md5)
  SRC_MD5="$(get_md5 "$SRC" || true)"
  DST_MD5="$(get_md5 "$DST" || true)"

  if [[ -n "$SRC_MD5" && -n "$DST_MD5" && "$SRC_MD5" == "$DST_MD5" ]]; then
    # Conteúdo igual: apaga origem (dedup)
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRYRUN DEDUP DELETE SRC (md5 igual): $SRC" | tee -a "$LOG"
    else
      gsutil rm "$SRC" >>"$LOG" 2>&1
      echo "DEDUP DELETED SRC (md5 igual): $SRC" | tee -a "$LOG"
    fi
    ((dedup_deleted++)) || true
  else
    # Conteúdo diferente: renomeia com sufixo pra não perder dado
    SUF="$(printf '%s' "$SRC" | sha1sum | awk '{print substr($1,1,10)}')"
    DST2="gs://$BUCKET/${KEY}__dup__${XX}${YY}__${SUF}"

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "DRYRUN CONFLICT RENAME: $SRC -> $DST2" | tee -a "$LOG"
    else
      gsutil mv "$SRC" "$DST2" >>"$LOG" 2>&1
      echo "CONFLICT RENAMED: $SRC -> $DST2" | tee -a "$LOG"
    fi
    ((conflict_renamed++)) || true
  fi

done < "$LIST"

echo "== RESUMO ==" | tee -a "$LOG"
echo "moved=$moved skipped=$skipped mismatch=$mismatch dedup_deleted=$dedup_deleted conflict_renamed=$conflict_renamed" | tee -a "$LOG"
echo "Log: $LOG" | tee -a "$LOG"