#!/usr/bin/env bash
set -euo pipefail

yaml="$(dirname "$0")/topics.yaml"

# simple YAML reader (env-free): parse name/overrides
parse_yaml() {
  awk '
  BEGIN { in_defaults=0 }
  /^defaults:/ { in_defaults=1; next }
  in_defaults==1 && NF==0 { in_defaults=0 }
  in_defaults==1 && $1 ~ /:/ {
    split($0,a,":"); gsub(/ /,"",a[1]); gsub(/^ +/,"",a[2]); def[a[1]]=a[2]
  }
  $1=="-"{ name=$3; gsub(/"/,"",name); print "topic="name }
  $1=="cleanup_policy:"{ print "cleanup_policy="$2 }
  $1=="partitions:"{ print "partitions="$2 }
  $1=="retention_ms:"{ print "retention_ms="$2 }
  ' "$yaml"
}

current=""
declare -A cfg
while IFS= read -r line; do
  if [[ "$line" == topic=* ]]; then
    # flush previous
    if [[ -n "${current:-}" ]]; then
      partitions="${cfg[partitions]:-3}"
      retention="${cfg[retention_ms]:-604800000}"
      policy="${cfg[cleanup_policy]:-delete}"
      echo "[topic] $current p=$partitions retention_ms=$retention policy=$policy"
      docker compose -f platform/docker-compose.dev.yaml \
        --env-file platform/.env.dev.sample \
        exec -T redpanda rpk topic create "$current" \
        --partitions "$partitions" \
        --replicas 1 \
        --retention-ms "$retention" \
        --cleanup-policy "$policy" >/dev/null 2>&1 || true
      cfg=()
    fi
    current="${line#topic=}"
  elif [[ "$line" == partitions=* ]]; then cfg[partitions]="${line#partitions=}"
  elif [[ "$line" == retention_ms=* ]]; then cfg[retention_ms]="${line#retention_ms=}"
  elif [[ "$line" == cleanup_policy=* ]]; then cfg[cleanup_policy]="${line#cleanup_policy=}"
  fi
done < <(parse_yaml)

# flush last
if [[ -n "${current:-}" ]]; then
  partitions="${cfg[partitions]:-3}"
  retention="${cfg[retention_ms]:-604800000}"
  policy="${cfg[cleanup_policy]:-delete}"
  echo "[topic] $current p=$partitions retention_ms=$retention policy=$policy"
  docker compose -f platform/docker-compose.dev.yaml \
    --env-file platform/.env.dev.sample \
    exec -T redpanda rpk topic create "$current" \
    --partitions "$partitions" \
    --replicas 1 \
    --retention-ms "$retention" \
    --cleanup-policy "$policy" >/dev/null 2>&1 || true
fi

echo "OK: topics ensured."
