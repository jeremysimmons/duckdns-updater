# Run in an elevated PowerShell session from this directory.
param(
    [Parameter(Mandatory=$true)][string]$Domains,
    [int]$IntervalMinutes = 5
)
$ErrorActionPreference = 'Stop'
if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1440) { throw 'IntervalMinutes must be 1 to 1440.' }
$normalized = (($Domains -split ',') | ForEach-Object { $_.Trim() -replace '\.duckdns\.org$','' }) -join ','
if ($normalized -notmatch '^[a-zA-Z0-9-]+(,[a-zA-Z0-9-]+)*$') { throw 'Domains must be DuckDNS subdomains, separated by commas.' }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run PowerShell as Administrator.' }
$updaterSource = Join-Path $PSScriptRoot 'Update-DuckDNS.ps1'
if (-not (Test-Path $updaterSource)) { throw 'Update-DuckDNS.ps1 must be next to installer.' }
$secret = Read-Host 'DuckDNS token' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try { $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token cannot be empty.' }
$base = Join-Path $env:ProgramData 'DuckDNS'
New-Item -ItemType Directory -Path $base -Force | Out-Null
# Limit config and scripts to SYSTEM + local Administrators.
& icacls.exe $base /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not secure DuckDNS directory ACL.' }
Copy-Item $updaterSource (Join-Path $base 'Update-DuckDNS.ps1') -Force
@{ domains=$normalized; token=$token } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $base 'config.json') -Encoding UTF8
$token = $null
$taskName = 'DuckDNS Updater'
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + (Join-Path $base 'Update-DuckDNS.ps1') + '"')
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
$taskPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $taskPrincipal -Force | Out-Null
Write-Host "Installed $taskName for $normalized (every $IntervalMinutes minutes)."
Start-ScheduledTask -TaskName $taskName
Write-Host "Log: $(Join-Path $base 'duckdns.log')"
