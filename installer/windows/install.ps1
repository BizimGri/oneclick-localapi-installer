param(
    [string]$SourcePath = "$PSScriptRoot\..\..\publish\win-x64",
    [string]$InstallPath = "C:\LocalApi",
    [string]$ServiceName = "LocalApi",
    [string]$Port = "5099",
    [ValidateSet("SqlServer", "PostgreSql", "Sqlite")]
    [string]$DatabaseProvider = "Sqlite",
    [switch]$InstallDbServer
)

$ErrorActionPreference = "Stop"

function Assert-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Bu script yönetici olarak çalıştırılmalıdır."
    }
}

function Test-CommandExists([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-DotNetRuntimeIfNeeded {
    if (Test-Path "$InstallPath\LocalApi.exe") {
        Write-Host "Self-contained publish tespit edildi; runtime kurulumu atlanıyor."
        return
    }

    if (Test-CommandExists "dotnet") {
        Write-Host "dotnet bulundu."
        return
    }

    if (Test-CommandExists "winget") {
        Write-Host "dotnet runtime winget ile kuruluyor..."
        winget install --id Microsoft.DotNet.Runtime.8 --accept-source-agreements --accept-package-agreements --silent
        return
    }

    if (Test-CommandExists "choco") {
        Write-Host "dotnet runtime choco ile kuruluyor..."
        choco install dotnet-8.0-runtime -y
        return
    }

    throw "dotnet runtime bulunamadı ve winget/choco yok. Manuel kurulum gerekli."
}

function Install-DbServerIfRequested {
    if (-not $InstallDbServer) {
        return
    }

    switch ($DatabaseProvider) {
        "SqlServer" {
            if (-not (Test-CommandExists "sqlcmd")) {
                if (Test-CommandExists "winget") {
                    winget install --id Microsoft.SQLServer.2022.Express --accept-source-agreements --accept-package-agreements --silent
                } else {
                    Write-Warning "SQL Server Express otomatik kurulumu için winget bulunamadı."
                }
            }
        }
        "PostgreSql" {
            if (-not (Get-Service -Name postgresql* -ErrorAction SilentlyContinue)) {
                if (Test-CommandExists "winget") {
                    winget install --id PostgreSQL.PostgreSQL.16 --accept-source-agreements --accept-package-agreements --silent
                } else {
                    Write-Warning "PostgreSQL otomatik kurulumu için winget bulunamadı."
                }
            }
        }
        "Sqlite" {
            Write-Host "Sqlite için ayrı server kurulumu gerekmiyor."
        }
    }
}

function Ensure-ValidProductionConfig {
    param(
        [string]$Path,
        [string]$Provider,
        [string]$BaseInstallPath
    )

    $needRewrite = $false
    if (Test-Path $Path) {
        try {
            Get-Content -Raw -Path $Path | ConvertFrom-Json | Out-Null
        }
        catch {
            Write-Warning "Mevcut appsettings.Production.json gecersiz. Yeniden olusturuluyor."
            $needRewrite = $true
        }
    }
    else {
        $needRewrite = $true
    }

    if (-not $needRewrite) {
        return
    }

    $sqlitePath = ($BaseInstallPath -replace '\\', '/') + '/localapi.db'

    $config = [ordered]@{
        DatabaseProvider = $Provider
        ConnectionStrings = [ordered]@{
            SqlServer = "Server=localhost,1433;Database=LocalApiDb;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;"
            PostgreSql = "Host=localhost;Port=5432;Database=localapidb;Username=postgres;Password=postgres;"
            Sqlite = "Data Source=$sqlitePath"
        }
        Logging = [ordered]@{
            LogLevel = [ordered]@{
                Default = "Information"
                "Microsoft.AspNetCore" = "Warning"
            }
        }
        AllowedHosts = "*"
    }

    $config | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding utf8
}

Assert-Admin

if (-not (Test-Path $SourcePath)) {
    throw "Publish klasörü bulunamadı: $SourcePath"
}

# Stop service before file copy to avoid locked runtime binaries during upgrade.
$existingBeforeCopy = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -ne $existingBeforeCopy) {
    if ($existingBeforeCopy.Status -ne 'Stopped') {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    $maxWaitSec = 20
    $elapsed = 0
    while ($elapsed -lt $maxWaitSec) {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($null -eq $svc -or $svc.Status -eq 'Stopped') {
            break
        }

        Start-Sleep -Seconds 1
        $elapsed++
    }
}

New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
Copy-Item -Path "$SourcePath\*" -Destination $InstallPath -Recurse -Force

Install-DotNetRuntimeIfNeeded
Install-DbServerIfRequested

$prodConfigPath = Join-Path $InstallPath "appsettings.Production.json"
Ensure-ValidProductionConfig -Path $prodConfigPath -Provider $DatabaseProvider -BaseInstallPath $InstallPath

$env:ASPNETCORE_ENVIRONMENT = "Production"
$env:ASPNETCORE_URLS = "http://0.0.0.0:$Port"

Push-Location $InstallPath
try {
    & "$InstallPath\LocalApi.exe" --migrate
} finally {
    Pop-Location
}

$binaryPath = "`"$InstallPath\LocalApi.exe`" --urls http://0.0.0.0:$Port"
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    sc.exe create $ServiceName binPath= $binaryPath start= auto | Out-Null
} else {
    sc.exe config $ServiceName binPath= $binaryPath start= auto | Out-Null
}

Start-Service -Name $ServiceName
Set-Service -Name $ServiceName -StartupType Automatic

$ruleName = "LocalApi-$Port"
$ruleExists = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($null -eq $ruleExists) {
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
}

Write-Host "Kurulum tamamlandı. Service: $ServiceName, Port: $Port"
