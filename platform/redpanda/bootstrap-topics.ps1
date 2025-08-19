Param()
$ErrorActionPreference = "Stop"

$yaml = Get-Content (Join-Path $PSScriptRoot "topics.yaml")
$defaults = @{
  partitions = 3
  retention_ms = 604800000
  cleanup_policy = "delete"
}
$topics = @()
$current = @{}

foreach ($line in $yaml) {
  if ($line -match '^\s*-\s+name:\s+(.+)$') {
    if ($current.ContainsKey("name")) { $topics += $current; $current = @{} }
    $current["name"] = $Matches[1].Trim()
  } elseif ($line -match '^\s*partitions:\s+(\d+)') {
    $current["partitions"] = [int]$Matches[1]
  } elseif ($line -match '^\s*retention_ms:\s+(\d+)') {
    $current["retention_ms"] = [int64]$Matches[1]
  } elseif ($line -match '^\s*cleanup_policy:\s+(\w+)') {
    $current["cleanup_policy"] = $Matches[1]
  }
}
if ($current.ContainsKey("name")) { $topics += $current }

foreach ($t in $topics) {
  $name = $t["name"]
  $p = if ($t.ContainsKey("partitions")) { $t["partitions"] } else { $defaults["partitions"] }
  $r = if ($t.ContainsKey("retention_ms")) { $t["retention_ms"] } else { $defaults["retention_ms"] }
  $cp = if ($t.ContainsKey("cleanup_policy")) { $t["cleanup_policy"] } else { $defaults["cleanup_policy"] }
  Write-Host "[topic] $name p=$p retention_ms=$r policy=$cp"
  docker compose -f platform/docker-compose.dev.yaml --env-file platform/.env.dev.sample `
    exec -T redpanda rpk topic create $name --partitions $p --replicas 1 `
    --retention-ms $r --cleanup-policy $cp 2>$null | Out-Null
}
Write-Host "OK: topics ensured."
