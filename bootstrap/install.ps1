param(
    [string]$RepoUrl = "https://github.com/BizimGri/oneclick-localapi-installer.git",
    [string]$TargetDir = "$(Join-Path $PSScriptRoot 'oneclick-localapi-installer')"
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
        "-File", ('"' + $PSCommandPath + '"'),
        "-RepoUrl", ('"' + $RepoUrl + '"'),
        "-TargetDir", ('"' + $TargetDir + '"')
    )

    Write-Host "[INFO] Admin yetkisi gerekiyor. UAC penceresi acilacak..."
    Start-Process -FilePath "powershell.exe" -ArgumentList ($argList -join ' ') -Verb RunAs | Out-Null
}

function Test-CommandExists([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Ensure-Git {
    if (Test-CommandExists "git") {
        return
    }

    Write-Host "[STEP] git bulunamadi. Otomatik kurulum deneniyor..."

    if (Test-CommandExists "winget") {
        winget install --id Git.Git --accept-source-agreements --accept-package-agreements --silent | Out-Null
    }
    elseif (Test-CommandExists "choco") {
        choco install git -y | Out-Null
    }
    else {
        throw "git bulunamadi ve winget/choco yok. Once git kurun."
    }

    if (-not (Test-CommandExists "git")) {
        $gitExe = "$env:ProgramFiles\Git\cmd\git.exe"
        if (Test-Path $gitExe) {
            $env:PATH = "$env:PATH;$env:ProgramFiles\Git\cmd"
        }
    }

    if (-not (Test-CommandExists "git")) {
        throw "git kuruldu ancak mevcut shell'de bulunamadi. Yeni terminal acip tekrar deneyin."
    }
}

$defaultTargetDir = Join-Path $PSScriptRoot "oneclick-localapi-installer"

if (-not (Test-Admin)) {
    Relaunch-Elevated
    exit 0
}

Ensure-Git

if (Test-Path (Join-Path $TargetDir ".git")) {
    Write-Host "[STEP] Repo guncelleniyor: $TargetDir"
    git -C $TargetDir pull --ff-only
}
else {
    Write-Host "[STEP] Repo klonlaniyor: $RepoUrl -> $TargetDir"
    git clone $RepoUrl $TargetDir
}

$installer = Join-Path $TargetDir "installer\\windows\\oneclick-install.cmd"
if (-not (Test-Path $installer)) {
    throw "Installer bulunamadi: $installer"
}

Write-Host "[STEP] Windows one-click install calistiriliyor..."
& $installer
if ($LASTEXITCODE -ne 0) {
    throw "Kurulum basarisiz."
}

if ($TargetDir -eq $defaultTargetDir -and (Test-Path $TargetDir)) {
    Write-Host "[STEP] Gecici bootstrap klasoru temizleniyor: $TargetDir"
    Remove-Item -Path $TargetDir -Recurse -Force
}

Write-Host "[OK] Kurulum tamamlandi."
