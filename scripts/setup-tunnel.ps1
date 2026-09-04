[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^tunnel_[0-9a-f]{32}$')]
    [string]$TunnelId,
    [string]$OrganizationId = 'org-Ku85qrWdADBgvNx2WZyjju4O',
    [string]$SkillsRoot = 'D:\Projects\Github\chatgpt-skills'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$tunnelDir = Join-Path $projectRoot '.tunnel'
$configPath = Join-Path $tunnelDir 'config.json'
$keyPath = Join-Path $tunnelDir 'control-plane-api-key.dpapi'
$defaultClient = Join-Path (Split-Path -Parent $projectRoot) 'ChatGPTMCP\tools\tunnel-client-v0.0.13\tunnel-client.exe'
$clientPath = if ([string]::IsNullOrWhiteSpace($env:TUNNEL_CLIENT_PATH)) { $defaultClient } else { $env:TUNNEL_CLIENT_PATH }

if (-not (Test-Path -LiteralPath $clientPath -PathType Leaf)) { throw "Tunnel client not found: $clientPath" }
New-Item -ItemType Directory -Force $tunnelDir | Out-Null

$secureKey = Read-Host 'OpenAI tunnel Runtime API key (requires Tunnels Read + Use)' -AsSecureString
$runtimeKey = $null
$hadControlPlaneKey = Test-Path Env:CONTROL_PLANE_API_KEY
$previousControlPlaneKey = $env:CONTROL_PLANE_API_KEY
$hadAdminKey = Test-Path Env:OPENAI_ADMIN_KEY
$previousAdminKey = $env:OPENAI_ADMIN_KEY

try {
    $runtimeKey = [Net.NetworkCredential]::new('', $secureKey).Password
    if ([string]::IsNullOrWhiteSpace($runtimeKey) -or -not $runtimeKey.StartsWith('sk-')) {
        throw 'The supplied value is not a valid OpenAI runtime API key.'
    }

    # Validate the runtime key against the exact tunnel before persisting it.
    # Force runtime-key auth so a valid admin key cannot mask a bad runtime key.
    $env:CONTROL_PLANE_API_KEY = $runtimeKey
    Remove-Item Env:OPENAI_ADMIN_KEY -ErrorAction SilentlyContinue
    $null = & $clientPath admin tunnels get $TunnelId --json 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Runtime API key cannot read tunnel $TunnelId. Create a Runtime API key at https://platform.openai.com/settings/organization/api-keys and ensure its principal has Tunnels Read + Use."
    }

    $config = [ordered]@{
        tunnelId = $TunnelId
        organizationId = $OrganizationId
        skillsRoot = [IO.Path]::GetFullPath($SkillsRoot)
    }
    $config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8

    if (Test-Path -LiteralPath $keyPath -PathType Leaf) {
        $backupPath = "$keyPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $keyPath -Destination $backupPath -Force
        Write-Host "Previous DPAPI key backed up to $backupPath"
    }

    $cipherText = ConvertFrom-SecureString $secureKey
    # Write without CR/LF so ConvertTo-SecureString round-trips reliably in
    # both Windows PowerShell and pwsh.
    [IO.File]::WriteAllText($keyPath, $cipherText, [Text.Encoding]::ASCII)

    Write-Host 'Skill Hub tunnel config and validated Runtime API key saved locally.'
    Write-Host 'Start with .\scripts\start-tunnel.ps1'
}
finally {
    if ($hadControlPlaneKey) {
        $env:CONTROL_PLANE_API_KEY = $previousControlPlaneKey
    } else {
        Remove-Item Env:CONTROL_PLANE_API_KEY -ErrorAction SilentlyContinue
    }

    if ($hadAdminKey) {
        $env:OPENAI_ADMIN_KEY = $previousAdminKey
    } else {
        Remove-Item Env:OPENAI_ADMIN_KEY -ErrorAction SilentlyContinue
    }

    $runtimeKey = $null
    $previousControlPlaneKey = $null
    $previousAdminKey = $null
    if ($null -ne $secureKey) { $secureKey.Dispose() }
}
