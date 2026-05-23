param(
    [string]$InstallPath = "C:\LocalApi",
    [string]$ServiceName = "LocalApi",
    [string]$Port = "5099"
)

$ErrorActionPreference = "Stop"

function Assert-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Bu script yonetici olarak calistirilmalidir."
    }
}

Assert-Admin

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -ne $service) {
    if ($service.Status -ne 'Stopped') {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    sc.exe delete $ServiceName | Out-Null

    # Wait a bit for SCM to finalize deletion to avoid locked-file leftovers.
    $maxWaitSec = 15
    $elapsed = 0
    while ($elapsed -lt $maxWaitSec -and (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)) {
        Start-Sleep -Seconds 1
        $elapsed++
    }
}

$ruleName = "LocalApi-$Port"
$rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($null -ne $rule) {
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
}

if (Test-Path $InstallPath) {
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop
}

Write-Host "Kaldirma tamamlandi."
