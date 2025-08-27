[CmdletBinding()]
param(
  [string]$BaseUrl = "http://localhost:7001",
  [string]$Gln     = "8690000000000",
  [string]$Email   = "kalfa1@demo.local",
  [string]$Password= "Assistant!234"
)

function Invoke-Json {
  param(
    [Parameter(Mandatory=$true)][ValidateSet('GET','POST')] [string]$Method,
    [Parameter(Mandatory=$true)] [string]$Url,
    [hashtable]$Data
  )
  try {
    if ($Data) { $json = $Data | ConvertTo-Json -Depth 5 }
    if ($Method -eq 'GET') {
      $res = Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop
    } else {
      $res = Invoke-RestMethod -Uri $Url -Method Post -Body $json -ContentType "application/json" -ErrorAction Stop
    }
    return @{ ok = $true; data = $res }
  } catch {
    $resp = $_.Exception.Response
    if ($resp -ne $null) {
      $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
      $text = $reader.ReadToEnd()
      Write-Host ("HTTP {0} {1}" -f $resp.StatusCode, $resp.StatusDescription) -ForegroundColor Red
      Write-Host $text -ForegroundColor DarkYellow
    } else {
      Write-Host $_.Exception.Message -ForegroundColor Red
    }
    return @{ ok = $false }
  }
}

Write-Host "=== OPAS Auth Smoke Test ===" -ForegroundColor Cyan

# 1) /healthz
$r = Invoke-Json -Method GET -Url "$BaseUrl/healthz"
if (-not $r.ok -or $r.data -ne "OK") {
  Write-Host "healthz FAILED" -ForegroundColor Red; exit 1
} else {
  Write-Host "healthz OK: $($r.data)" -ForegroundColor Green
}

# 2) /db/ping
$r = Invoke-Json -Method GET -Url "$BaseUrl/db/ping"
if (-not $r.ok -or -not $r.data.ok) {
  Write-Host "db/ping FAILED" -ForegroundColor Red; exit 1
} else {
  Write-Host "db ping OK -> result=$($r.data.result)" -ForegroundColor Green
}

# 3) /auth/login
$loginReq = @{ gln=$Gln; email=$Email; password=$Password }
$r = Invoke-Json -Method POST -Url "$BaseUrl/auth/login" -Data $loginReq
if (-not $r.ok) {
  Write-Host "login FAILED" -ForegroundColor Red; exit 2
}
$SID = $r.data.session_id
$RT  = $r.data.refresh_token
Write-Host "login OK -> sid=$SID" -ForegroundColor Green

# 4) /auth/claims
$r = Invoke-Json -Method GET -Url "$BaseUrl/auth/claims?sid=$SID"
if (-not $r.ok) {
  Write-Host "claims FAILED" -ForegroundColor Red; exit 3
} else {
  Write-Host "claims OK:" -ForegroundColor Green
  $r.data | Format-Table | Out-String | Write-Host
}

# 5) /auth/refresh
$r = Invoke-Json -Method POST -Url "$BaseUrl/auth/refresh" -Data @{ refresh_token = $RT }
if (-not $r.ok) {
  Write-Host "refresh FAILED" -ForegroundColor Red; exit 4
} else {
  Write-Host "refresh OK:" -ForegroundColor Green
  $r.data | Format-Table | Out-String | Write-Host
}

# 6) /auth/logout
$r = Invoke-Json -Method POST -Url "$BaseUrl/auth/logout" -Data @{ sid = $SID }
# 204 No Content döndüğü için body yok; Exception atmadıysa OK sayıyoruz
if (-not $r.ok) {
  Write-Host "logout FAILED" -ForegroundColor Yellow
} else {
  Write-Host "logout OK" -ForegroundColor Green
}

Write-Host "ALL GOOD " -ForegroundColor Green
exit 0
