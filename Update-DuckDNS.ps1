# Requires Windows PowerShell 5.1 or PowerShell 7+
$ErrorActionPreference = 'Stop'
$base = Join-Path $env:ProgramData 'DuckDNS'
$configFile = Join-Path $base 'config.json'
$logFile = Join-Path $base 'duckdns.log'

function Write-Log([string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Add-Content -LiteralPath $logFile -Value $line
    Write-Output $line
}

try {
    if (-not (Test-Path -LiteralPath $configFile)) { throw 'Configuration missing. Run Install-DuckDNS.ps1 as Administrator.' }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    if (-not $config.domains -or -not $config.token) { throw 'Missing domains or token in configuration.' }
    $domains = [string]$config.domains
    $token = [string]$config.token
    $url = 'https://www.duckdns.org/update?domains=' + [uri]::EscapeDataString($domains) + '&token=' + [uri]::EscapeDataString($token)
    # Avoid leaking the token into an error log.
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30 -ErrorAction Stop
        $body = ([string]$response.Content).Trim()
    } catch { throw "DuckDNS HTTPS request failed: $($_.Exception.Message -replace [regex]::Escape($token),'[REDACTED]')" }
    if ($body -notmatch '^OK(?:\s|$)') { throw "DuckDNS rejected update (response: $($body -replace [regex]::Escape($token),'[REDACTED]'))" }
    Write-Log "OK domains=$domains"
} catch {
    $message = $_.Exception.Message
    if ($token) { $message = $message.Replace($token, '[REDACTED]') }
    Write-Log "ERROR $message"
    exit 1
}
