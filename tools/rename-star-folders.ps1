Param()

$ErrorActionPreference = "Stop"

$map = @{
  "apps/★-tenant-provisioning" = "apps/star-tenant-provisioning"
  "apps/★-consent-privacy"     = "apps/star-consent-privacy"
  "apps/★-rules-engine"        = "apps/star-rules-engine"
  "apps/★-workflow-orchestrator" = "apps/star-workflow-orchestrator"
  "apps/★-lakehouse-bi"        = "apps/star-lakehouse-bi"
}

foreach ($kvp in $map.GetEnumerator()) {
  $src = $kvp.Key
  $dst = $kvp.Value
  if (Test-Path -Path $src -PathType Container) {
    if (Test-Path -Path $dst -PathType Container) {
      Write-Host "[skip] Target exists: $dst"
      continue
    }
    Write-Host "[move] $src -> $dst"
    Rename-Item -Path $src -NewName (Split-Path $dst -Leaf)
  } else {
    Write-Host "[skip] Not found: $src"
  }
}

Write-Host "Done. Update solution/pipeline references if needed."
