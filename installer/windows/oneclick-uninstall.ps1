param(
    [string]$InstallPath = "C:\LocalApi",
    [string]$ServiceName = "LocalApi",
    [string]$Port = "5099"
)

$ErrorActionPreference = "Stop"

function Test-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Relaunch-Elevated {
    $argList = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ('"' + $PSCommandPath + '"')
    )

    foreach ($arg in $MyInvocation.BoundParameters.GetEnumerator()) {
        $name = "-$($arg.Key)"
        if ($arg.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($arg.Value.IsPresent) { $argList += $name }
            continue
        }
        $argList += $name
        $argList += ('"' + [string]$arg.Value + '"')
    }

    Write-Host "[INFO] Admin yetkisi gerekiyor. UAC penceresi acilacak..."
    Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join ' ') -Verb RunAs | Out-Null
}

$scriptDir = Split-Path -Parent $PSCommandPath
$rootDir = Resolve-Path (Join-Path $scriptDir "..\..")
$uninstallScript = Join-Path $rootDir "installer\windows\uninstall.ps1"

if (-not (Test-Admin)) {
    Relaunch-Elevated
    exit 0
}

if (-not (Test-Path $uninstallScript)) {
    throw "Uninstall script bulunamadi: $uninstallScript"
}

Write-Host "[STEP] Uninstall baslatiliyor..."
& powershell -NoProfile -ExecutionPolicy Bypass -File $uninstallScript -InstallPath $InstallPath -ServiceName $ServiceName -Port $Port
if ($LASTEXITCODE -ne 0) {
    throw "Uninstall basarisiz."
}

Write-Host "[OK] Kaldirma tamamlandi."
