#!/usr/bin/env bash
set -euo pipefail

declare -A MAP=(
  ["apps/★-tenant-provisioning"]="apps/star-tenant-provisioning"
  ["apps/★-consent-privacy"]="apps/star-consent-privacy"
  ["apps/★-rules-engine"]="apps/star-rules-engine"
  ["apps/★-workflow-orchestrator"]="apps/star-workflow-orchestrator"
  ["apps/★-lakehouse-bi"]="apps/star-lakehouse-bi"
)

moved_any=0
for src in "${!MAP[@]}"; do
  dst="${MAP[$src]}"
  if [ -d "$src" ]; then
    if [ -d "$dst" ]; then
      echo "[skip] Target exists: $dst"
      continue
    fi
    echo "[move] $src -> $dst"
    mv "$src" "$dst"
    moved_any=1
  else
    echo "[skip] Not found: $src"
  fi
done

if [ "$moved_any" -eq 1 ]; then
  echo "Done. Update references in solution files and pipelines if needed."
else
  echo "No moves performed."
fi
