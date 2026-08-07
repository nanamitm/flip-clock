<#
.SYNOPSIS
    Configure and build the Windows (MSVC x64) target.

.DESCRIPTION
    Resolves Qt, CMake, Ninja and the MSVC toolchain (see tools/common.ps1),
    then runs the matching CMake preset. Override any part of the toolchain by
    setting QT_DIR_DESKTOP before running.

.EXAMPLE
    ./tools/build-windows.ps1                 # debug build
    ./tools/build-windows.ps1 -Config release # release build
    ./tools/build-windows.ps1 -Run            # build, then launch the app
#>
[CmdletBinding()]
param(
    [ValidateSet('debug', 'release')]
    [string]$Config = 'debug',

    [switch]$Clean,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$repoRoot = Split-Path -Parent $PSScriptRoot
$preset = "windows-msvc-$Config"
$buildDir = Join-Path $repoRoot "build/$preset"

Initialize-BuildEnv -Msvc

if ($Clean -and (Test-Path $buildDir)) {
    Write-Host "Removing $buildDir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}

# CMake and Ninja write progress and warnings to stderr. Under
# ErrorActionPreference = Stop that turns a harmless warning into a thrown
# error, so from here on the native tools are judged by their exit codes.
$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false

Push-Location $repoRoot
try {
    cmake --preset $preset
    if ($LASTEXITCODE -ne 0) { throw "configure failed ($LASTEXITCODE)" }

    cmake --build --preset $preset
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

    $exe = Join-Path $buildDir 'appFlipClock.exe'
    Write-Host ''
    Write-Host "Built: $exe" -ForegroundColor Green

    if ($Run) {
        # The build tree has no Qt DLLs beside the exe; point at the kit.
        $env:PATH = "$env:QT_DIR_DESKTOP\bin;$env:PATH"
        & $exe
    }
}
finally {
    Pop-Location
}
