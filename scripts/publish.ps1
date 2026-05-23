param(
    [string]$Configuration = "Release",
    [string]$Runtime
)

$ErrorActionPreference = "Stop"

function Test-CommandExists([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-DotNetCommand {
    $cmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        "$env:ProgramFiles\dotnet\dotnet.exe",
        "$env:ProgramFiles(x86)\dotnet\dotnet.exe",
        "$env:LOCALAPPDATA\Microsoft\dotnet\dotnet.exe"
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    return $null
}

function Add-DotNetToProcessPath {
    $dotnetDirs = @(
        "$env:ProgramFiles\dotnet",
        "$env:ProgramFiles(x86)\dotnet",
        "$env:LOCALAPPDATA\Microsoft\dotnet"
    )

    $currentPath = $env:PATH -split ';'
    foreach ($dir in $dotnetDirs) {
        if (-not $dir -or -not (Test-Path $dir)) {
            continue
        }

        if ($currentPath -notcontains $dir) {
            $env:PATH = "$env:PATH;$dir"
        }
    }
}

function Ensure-DotNetSdk {
    $existing = Get-DotNetCommand
    if ($existing) {
        return [string]$existing
    }

    Write-Host "dotnet bulunamadi. Otomatik kurulum deneniyor..."

    if (Test-CommandExists "winget") {
        winget install --id Microsoft.DotNet.SDK.8 --accept-source-agreements --accept-package-agreements --silent | Out-Null
    }
    elseif (Test-CommandExists "choco") {
        choco install dotnet-8.0-sdk -y | Out-Null
    }
    else {
        throw "dotnet SDK bulunamadi ve winget/choco yok. Manuel kurulum: https://dotnet.microsoft.com/download"
    }

    Add-DotNetToProcessPath
    $installed = Get-DotNetCommand
    if (-not $installed) {
        throw "dotnet kuruldu ancak tespit edilemedi. Yeni terminal acip tekrar deneyin."
    }

    return [string]$installed
}

function Get-CurrentRuntime {
    $os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    $isWindowsOs = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
    $isLinuxOs = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
    $isMacOs = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)
    $isArm = $env:PROCESSOR_ARCHITECTURE -match 'ARM64'

    if ($isWindowsOs) {
        return $(if ($isArm) { 'win-arm64' } else { 'win-x64' })
    }
    if ($isLinuxOs) {
        return $(if ($isArm) { 'linux-arm64' } else { 'linux-x64' })
    }
    if ($isMacOs) {
        return $(if ($isArm) { 'osx-arm64' } else { 'osx-x64' })
    }

    throw "Desteklenmeyen isletim sistemi: $os"
}

$dotnetCmd = [string](Ensure-DotNetSdk)

$root = (Resolve-Path "$PSScriptRoot\..").Path
$project = Join-Path $root "src\LocalApi\LocalApi.csproj"
$outBase = Join-Path $root "publish"

if (-not (Test-Path $project)) {
    throw "Proje dosyasi bulunamadi: $project"
}

$runtime = if ($Runtime) { $Runtime } else { Get-CurrentRuntime }
$outDir = Join-Path $outBase $runtime

Write-Host "Publishing $runtime -> $outDir"
& $dotnetCmd publish $project -c $Configuration -r $runtime --self-contained true -o $outDir

Write-Host "Publish tamamlandi."
