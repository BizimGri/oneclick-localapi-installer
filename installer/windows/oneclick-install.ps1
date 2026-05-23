param(
    [string]$SourcePath,
    [string]$InstallPath = "C:\LocalApi",
    [string]$Port = "5099",
    [ValidateSet("SqlServer", "PostgreSql", "Sqlite")]
    [string]$DatabaseProvider = "Sqlite",
    [switch]$InstallDbServer,
    [switch]$SkipPublish
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

function Get-WindowsRuntime {
    $isArm = $env:PROCESSOR_ARCHITECTURE -match 'ARM64'
    if ($isArm) { return 'win-arm64' }
    return 'win-x64'
}

$scriptDir = Split-Path -Parent $PSCommandPath
$rootDir = Resolve-Path (Join-Path $scriptDir "..\..")

$publishScript = Join-Path $rootDir "scripts\publish.ps1"
$installScript = Join-Path $rootDir "installer\windows\install.ps1"

if (-not (Test-Admin)) {
    Relaunch-Elevated
    exit 0
}

Write-Host "[INFO] Root: $rootDir"

if (-not (Test-Path $publishScript)) {
    throw "Publish script bulunamadi: $publishScript"
}
if (-not (Test-Path $installScript)) {
    throw "Install script bulunamadi: $installScript"
}

if (-not $SkipPublish) {
    Write-Host "[STEP] Publish baslatiliyor..."
    $runtime = Get-WindowsRuntime
    & powershell -NoProfile -ExecutionPolicy Bypass -File $publishScript -Runtime $runtime
    if ($LASTEXITCODE -ne 0) {
        throw "Publish basarisiz."
    }

    if (-not $PSBoundParameters.ContainsKey('SourcePath')) {
        $SourcePath = Join-Path $rootDir ("publish\" + $runtime)
    }
} else {
    Write-Host "[STEP] Publish atlandi (-SkipPublish)."

    if (-not $SourcePath) {
        $SourcePath = Join-Path $rootDir "publish\win-x64"
    }
}

Write-Host "[STEP] Install baslatiliyor..."

$installArgs = @{
    SourcePath = $SourcePath
    InstallPath = $InstallPath
    Port = $Port
    DatabaseProvider = $DatabaseProvider
}
if ($InstallDbServer) {
    $installArgs["InstallDbServer"] = $true
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $installScript @installArgs
if ($LASTEXITCODE -ne 0) {
    throw "Install basarisiz."
}

Write-Host "[OK] Tum adimlar tamamlandi."
Write-Host "[OK] Test: curl http://127.0.0.1:$Port/api/products"
