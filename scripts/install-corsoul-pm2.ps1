[CmdletBinding()]
param(
  [switch] $SkipStartup
)

$ErrorActionPreference = 'Stop'
$CorsoulVersion = '0.1.5'
$Pm2Version = '7.0.3'
$ProcessName = 'corsoul-mcp'
$HealthUrl = 'http://127.0.0.1:3848/health'

function Invoke-Npm {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Arguments)
  & npm.cmd @Arguments
  if ($LASTEXITCODE -ne 0) { throw "npm failed with exit code $LASTEXITCODE" }
}

function Invoke-Pm2 {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]] $Arguments)
  & pm2.cmd @Arguments
  if ($LASTEXITCODE -ne 0) { throw "pm2 failed with exit code $LASTEXITCODE" }
}

if (-not (Get-Command node.exe -ErrorAction SilentlyContinue)) { throw 'Node.js 18 or newer is required.' }
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { throw 'npm is required.' }
$nodeMajor = [int]((& node.exe --version).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 18) { throw 'Node.js 18 or newer is required.' }

try {
  $health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2
  if ($health) {
    if (Get-Command pm2.cmd -ErrorAction SilentlyContinue) {
      & pm2.cmd describe $ProcessName *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Host "Corsoul is already healthy and managed as $ProcessName."
        Invoke-Pm2 save
        if (-not $SkipStartup) {
          Write-Host 'Ensuring the Windows PM2 login-startup hook is installed...'
          Invoke-Npm install --global --no-audit --no-fund pm2-windows-startup
          & pm2-startup.cmd install
          if ($LASTEXITCODE -ne 0) { throw 'PM2 is supervising Corsoul now, but the Windows startup hook failed. Run pm2-startup install manually, then pm2 save.' }
          Invoke-Pm2 save
        } else {
          Write-Warning 'Startup hook skipped. PM2 protects against crashes now, but Corsoul will not automatically return after reboot/login.'
        }
        exit 0
      }
    }
    throw 'Port 3848 already has a healthy owner that is not the managed corsoul-mcp process. Stop or migrate it explicitly; this installer will not replace it.'
  }
} catch {
  if ($_.Exception.Message -like 'Port 3848 already*') { throw }
}

Write-Host "Installing corsoul@$CorsoulVersion and pm2@$Pm2Version globally..."
Invoke-Npm install --global --no-audit --no-fund "corsoul@$CorsoulVersion" "pm2@$Pm2Version"

$globalRoot = (& npm.cmd root --global).Trim()
if ($LASTEXITCODE -ne 0 -or -not $globalRoot) { throw 'Unable to resolve the global npm package directory.' }
$serverScript = Join-Path $globalRoot 'corsoul\bin\cortex-mcp-local.js'
if (-not (Test-Path -LiteralPath $serverScript)) { throw "Corsoul server entrypoint not found: $serverScript" }

& pm2.cmd describe $ProcessName *> $null
if ($LASTEXITCODE -eq 0) { Invoke-Pm2 delete $ProcessName }

$savedDatabaseUrl = $env:DATABASE_URL
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
try {
  Invoke-Pm2 start $serverScript --name $ProcessName --interpreter node -- --transport=http --host=127.0.0.1 --port=3848
  Invoke-Pm2 save
} finally {
  if ($null -ne $savedDatabaseUrl) { Set-Item -Path Env:DATABASE_URL -Value $savedDatabaseUrl }
}

$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
  try {
    if (Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 2) { $healthy = $true; break }
  } catch {}
  Start-Sleep -Seconds 1
}
if (-not $healthy) { throw "PM2 started $ProcessName, but $HealthUrl did not become healthy. Run: pm2 logs $ProcessName" }

if (-not $SkipStartup) {
  Write-Host 'Installing the Windows PM2 login-startup hook...'
  Invoke-Npm install --global --no-audit --no-fund pm2-windows-startup
  & pm2-startup.cmd install
  if ($LASTEXITCODE -ne 0) { throw 'PM2 is supervising Corsoul now, but the Windows startup hook failed. Run pm2-startup install manually, then pm2 save.' }
  Invoke-Pm2 save
} else {
  Write-Warning 'Startup hook skipped. PM2 protects against crashes now, but Corsoul will not automatically return after reboot/login.'
}

Write-Host "Corsoul is healthy at $HealthUrl and managed by PM2 as $ProcessName."
Write-Host "Status: pm2 status | Logs: pm2 logs $ProcessName"
