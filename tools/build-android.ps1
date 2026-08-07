<#
.SYNOPSIS
    Configure and build the Android target, optionally packaging and installing.

.DESCRIPTION
    Resolves Qt (host and Android kits), a supported JDK, and the Android
    SDK/NDK (see tools/common.ps1), then runs the matching CMake preset. Qt's
    qt.toolchain.cmake chainloads the NDK toolchain; the host Qt supplies the
    code generators (moc, qmlcachegen, androiddeployqt).

.EXAMPLE
    ./tools/build-android.ps1                       # build the shared library
    ./tools/build-android.ps1 -Apk                  # ...and package an APK
    ./tools/build-android.ps1 -Apk -Install         # ...and adb install it
    ./tools/build-android.ps1 -Abi x86_64 -Apk -Install -Serial emulator-5554
#>
[CmdletBinding()]
param(
    [ValidateSet('arm64', 'x86_64')]
    [string]$Abi = 'arm64',

    [switch]$Clean,
    [switch]$Apk,
    [switch]$Install,

    # adb serial to install onto, for when more than one device is attached.
    [string]$Serial = ''
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/common.ps1"

$repoRoot = Split-Path -Parent $PSScriptRoot
$preset = "android-$Abi"
$buildDir = Join-Path $repoRoot "build/$preset"

Initialize-BuildEnv -Android

if ($Clean -and (Test-Path $buildDir)) {
    Write-Host "Removing $buildDir" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}

# CMake, Gradle and adb all write progress and warnings to stderr. Under
# ErrorActionPreference = Stop that turns a harmless warning into a thrown
# error, so from here on the native tools are judged by their exit codes.
$ErrorActionPreference = 'Continue'
$PSNativeCommandUseErrorActionPreference = $false

Push-Location $repoRoot
try {
    cmake --preset $preset
    if ($LASTEXITCODE -ne 0) { throw "configure failed ($LASTEXITCODE)" }

    if ($Apk) {
        cmake --build --preset "$preset-apk"
    } else {
        cmake --build --preset $preset
    }
    if ($LASTEXITCODE -ne 0) { throw "build failed ($LASTEXITCODE)" }

    if ($Apk) {
        # androiddeployqt copies the packaged APK to the top of android-build;
        # the Gradle intermediates below it are not the ones to install.
        $apkPath = Join-Path $buildDir 'android-build/appFlipClock.apk'
        if (-not (Test-Path $apkPath)) {
            $found = @(Get-ChildItem (Join-Path $buildDir 'android-build') -Recurse -Filter '*.apk' `
                -ErrorAction SilentlyContinue)
            if ($found.Count -eq 0) {
                throw "Build succeeded but no .apk was found under $buildDir/android-build"
            }
            $apkPath = $found[0].FullName
        }

        Write-Host ''
        Write-Host "APK: $apkPath" -ForegroundColor Green

        if ($Install) {
            $target = if ($Serial) { @('-s', $Serial) } else { @() }
            & adb @target install -r $apkPath
            if ($LASTEXITCODE -ne 0) { throw "adb install failed ($LASTEXITCODE)" }
            & adb @target shell am start -n 'com.example.flipclock/org.qtproject.qt.android.bindings.QtActivity'
        }
    }
}
finally {
    Pop-Location
}
