<#
.SYNOPSIS
    Shared build-environment discovery for the Flip Clock tool scripts.

.DESCRIPTION
    Dot-source this from any tools/*.ps1 script, then call Initialize-BuildEnv.
    It locates Qt, the MSVC toolchain, a supported JDK and the Android SDK/NDK,
    and exports them as the environment variables CMakePresets.json reads:

        QT_DIR_DESKTOP           full path to the desktop Qt kit
        QT_DIR_ANDROID_ARM64     full path to the android_arm64_v8a kit
        QT_DIR_ANDROID_X86_64    full path to the android_x86_64 kit
        ANDROID_SDK_ROOT
        ANDROID_NDK_ROOT
        JAVA_HOME

    Any of these that is already set is left alone, so CI (and anyone with a
    non-standard layout) can point the build wherever it likes without editing
    a checked-in file.

    This file only defines functions; it has no side effects when sourced.
#>

Set-StrictMode -Version Latest

# Qt 6.9 is the floor: the QML SafeArea attached type used by Main.qml to keep
# content clear of the Android status bar and gesture area arrived in 6.9.
$script:MinimumQtVersion = [version]'6.9'

# Qt 6.9-6.11 for Android are built against NDK r27; a mismatched NDK links but
# can fail at runtime in ways that are painful to diagnose.
$script:PreferredNdkPrefix = '27.'

# ---------------------------------------------------------------------------
# Qt
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Finds the Qt version directory (e.g. C:\Qt\6.11.1) holding the kit folders.
#>
function Find-QtVersionDir {
    if ($env:QT_VERSION_DIR -and (Test-Path $env:QT_VERSION_DIR)) {
        return (Resolve-Path $env:QT_VERSION_DIR).Path
    }

    $roots = @(
        $env:QT_INSTALL_ROOT
        'C:\Qt'
        'D:\Qt'
        (Join-Path $env:USERPROFILE 'Qt')
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($root in $roots) {
        $versions =
            Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d+\.\d+(\.\d+)?$' } |
            Where-Object { [version]$_.Name -ge $script:MinimumQtVersion } |
            Sort-Object { [version]$_.Name } -Descending

        foreach ($version in $versions) {
            # A version directory is only useful if it actually contains a
            # desktop kit; the Qt installer leaves stubs behind otherwise.
            $hasDesktopKit = Get-ChildItem $version.FullName -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^(msvc\d+_64|mingw_64|llvm-mingw_64|gcc_64|macos)$' }
            if ($hasDesktopKit) { return $version.FullName }
        }
    }

    return $null
}

<#
.SYNOPSIS
    Sets QT_DIR_DESKTOP and, with -Android, the Android kit variables.
#>
function Resolve-QtKits {
    [CmdletBinding()]
    param([switch]$Android)

    $needsDiscovery =
        (-not $env:QT_DIR_DESKTOP) -or
        ($Android -and -not ($env:QT_DIR_ANDROID_ARM64 -and $env:QT_DIR_ANDROID_X86_64))

    $versionDir = $null
    if ($needsDiscovery) {
        $versionDir = Find-QtVersionDir
        if (-not $versionDir) {
            throw ("No Qt $($script:MinimumQtVersion) or newer found. Install it, " +
                   'or set QT_VERSION_DIR (e.g. C:\Qt\6.11.1), or set QT_DIR_DESKTOP ' +
                   'and QT_DIR_ANDROID_* directly.')
        }
    }

    if (-not $env:QT_DIR_DESKTOP) {
        # MSVC first: it is what the Android kits expect as their host Qt on
        # Windows, and what CMakePresets.json's Windows presets target.
        $kit = Get-ChildItem $versionDir -Directory |
            Where-Object { $_.Name -match '^msvc\d+_64$' } |
            Sort-Object Name -Descending | Select-Object -First 1
        if (-not $kit) {
            $kit = Get-ChildItem $versionDir -Directory |
                Where-Object { $_.Name -in @('mingw_64', 'llvm-mingw_64', 'gcc_64') } |
                Select-Object -First 1
        }
        if (-not $kit) { throw "No desktop Qt kit under $versionDir." }
        $env:QT_DIR_DESKTOP = $kit.FullName
    }

    if ($Android) {
        foreach ($pair in @(
            @{ Var = 'QT_DIR_ANDROID_ARM64';  Kit = 'android_arm64_v8a' }
            @{ Var = 'QT_DIR_ANDROID_X86_64'; Kit = 'android_x86_64' }
        )) {
            if (Get-Item "env:$($pair.Var)" -ErrorAction SilentlyContinue) { continue }
            $path = Join-Path $versionDir $pair.Kit
            if (-not (Test-Path $path)) {
                throw ("Qt kit '$($pair.Kit)' is not installed under $versionDir. " +
                       'Add it with the Qt Maintenance Tool.')
            }
            Set-Item "env:$($pair.Var)" $path
        }
    }
}

<#
.SYNOPSIS
    Puts Qt's bundled CMake and Ninja on PATH when they are not there already.
#>
function Add-BuildToolsToPath {
    $candidates = @()

    $versionDir = if ($env:QT_DIR_DESKTOP) { Split-Path $env:QT_DIR_DESKTOP -Parent } else { $null }
    if ($versionDir) {
        $toolsDir = Join-Path (Split-Path $versionDir -Parent) 'Tools'
        foreach ($relative in @('CMake_64\bin', 'Ninja')) {
            $path = Join-Path $toolsDir $relative
            if (Test-Path $path) { $candidates += $path }
        }
    }

    if ($candidates.Count -gt 0) {
        $env:PATH = ($candidates -join ';') + ';' + $env:PATH
    }

    foreach ($tool in 'cmake', 'ninja') {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "$tool was not found on PATH and is not bundled with this Qt install."
        }
    }
}

# ---------------------------------------------------------------------------
# MSVC
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Imports the MSVC x64 environment into this session.

.DESCRIPTION
    The Ninja generator will not find cl.exe on its own. Does nothing when the
    script is already running inside a Developer PowerShell, which is also how
    the CI job (which uses msvc-dev-cmd) skips this.
#>
function Enter-MsvcEnvironment {
    if ($env:VCToolsInstallDir) { return }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    $installations = @()
    if (Test-Path $vswhere) {
        $installations = @(
            & $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
                -property installationPath -format value
        ) | Where-Object { $_ }
    }

    # Prefer a 2022 install: it matches the msvc2022_64 Qt kit exactly. Newer
    # toolsets are ABI-compatible and work fine as a fallback.
    $ordered = @($installations | Where-Object { $_ -match '2022' }) + @($installations | Where-Object { $_ -notmatch '2022' })

    foreach ($install in $ordered) {
        $vcvars = Join-Path $install 'VC\Auxiliary\Build\vcvars64.bat'
        if (-not (Test-Path $vcvars)) { continue }

        cmd /c "`"$vcvars`" >nul 2>&1 && set" | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') { Set-Item -Path "env:$($Matches[1])" -Value $Matches[2] }
        }
        return
    }

    throw 'No MSVC x64 toolset found. Install Visual Studio 2022 (or newer) with the "Desktop development with C++" workload.'
}

# ---------------------------------------------------------------------------
# JDK
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Reads a JDK's major version from its `release` manifest.

.DESCRIPTION
    Parsing the file rather than running `java -version` avoids the version
    banner, which java writes to stderr and which trips scripts running under
    ErrorActionPreference = Stop.
#>
function Get-JdkMajorVersion([string]$JdkHome) {
    if (-not $JdkHome -or -not (Test-Path (Join-Path $JdkHome 'bin\java.exe'))) { return $null }
    $release = Join-Path $JdkHome 'release'
    if (-not (Test-Path $release)) { return $null }

    $match = Select-String -Path $release -Pattern '^JAVA_VERSION="([0-9]+)' | Select-Object -First 1
    if ($match) { return [int]$match.Matches[0].Groups[1].Value }
    return $null
}

<#
.SYNOPSIS
    Points JAVA_HOME at a JDK the Android Gradle Plugin supports (17-21).

.DESCRIPTION
    AGP fails on JDK 22 and newer while transforming core-for-system-modules.jar
    (jlink reports an unsupported class file version), so a newer JDK already on
    JAVA_HOME has to be replaced rather than trusted.
#>
function Resolve-Jdk {
    $current = Get-JdkMajorVersion $env:JAVA_HOME
    if ($null -ne $current -and $current -ge 17 -and $current -le 21) { return }

    $candidates = @()
    $candidates += Get-ChildItem 'C:\Program Files\Microsoft\jdk-*',
                                 'C:\Program Files\Eclipse Adoptium\jdk-*',
                                 'C:\Program Files\Java\jdk-*' `
        -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    $candidates += 'C:\Program Files\Android\Android Studio\jbr'

    $picked = $candidates | Where-Object {
        $version = Get-JdkMajorVersion $_
        $null -ne $version -and $version -ge 17 -and $version -le 21
    } | Select-Object -First 1

    if (-not $picked) {
        throw ("No JDK 17-21 found (JAVA_HOME is '$env:JAVA_HOME'" +
               $(if ($null -ne $current) { ", major version $current" } else { '' }) +
               '). The Android Gradle Plugin does not support JDK 22 or newer.')
    }

    Write-Host "Using JDK $(Get-JdkMajorVersion $picked) at $picked" -ForegroundColor Cyan
    $env:JAVA_HOME = $picked
}

# ---------------------------------------------------------------------------
# Android SDK / NDK
# ---------------------------------------------------------------------------

function Resolve-AndroidSdk {
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        $env:ANDROID_HOME = $env:ANDROID_SDK_ROOT
        return
    }
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
        return
    }

    $default = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    if (-not (Test-Path $default)) {
        throw 'Android SDK not found. Install it, or set ANDROID_SDK_ROOT.'
    }
    $env:ANDROID_SDK_ROOT = $default
    $env:ANDROID_HOME = $default
}

function Resolve-AndroidNdk {
    if ($env:ANDROID_NDK_ROOT -and (Test-Path $env:ANDROID_NDK_ROOT)) { return }

    $ndkRoot = Join-Path $env:ANDROID_SDK_ROOT 'ndk'
    $installed = @(
        Get-ChildItem $ndkRoot -Directory -ErrorAction SilentlyContinue |
            Sort-Object { [version]$_.Name } -Descending
    )
    if ($installed.Count -eq 0) {
        throw "No NDK found under $ndkRoot. Install one (r27 is what Qt 6.9-6.11 expect), or set ANDROID_NDK_ROOT."
    }

    $preferred = $installed | Where-Object { $_.Name.StartsWith($script:PreferredNdkPrefix) } | Select-Object -First 1
    if ($preferred) {
        $env:ANDROID_NDK_ROOT = $preferred.FullName
        return
    }

    $env:ANDROID_NDK_ROOT = $installed[0].FullName
    Write-Warning ("NDK r$($script:PreferredNdkPrefix)x not installed; falling back to $($installed[0].Name). " +
                   'Qt for Android is built against r27, so a different NDK may produce runtime failures.')
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

<#
.SYNOPSIS
    Prepares this session for a build and reports what it resolved.

.PARAMETER Android
    Also resolve the Android kits, SDK, NDK and JDK.

.PARAMETER Msvc
    Import the MSVC environment (needed for the Windows build, not for Android).
#>
function Initialize-BuildEnv {
    [CmdletBinding()]
    param(
        [switch]$Android,
        [switch]$Msvc
    )

    Resolve-QtKits -Android:$Android
    Add-BuildToolsToPath

    if ($Msvc) { Enter-MsvcEnvironment }

    if ($Android) {
        Resolve-Jdk
        Resolve-AndroidSdk
        Resolve-AndroidNdk
        $env:PATH = "$env:JAVA_HOME\bin;$env:ANDROID_SDK_ROOT\platform-tools;$env:PATH"
    }

    Write-BuildEnvSummary -Android:$Android
}

<#
.SYNOPSIS
    Prints the resolved toolchain, so a failed build says which Qt it used.
#>
function Write-BuildEnvSummary {
    [CmdletBinding()]
    param([switch]$Android)

    $names = @('QT_DIR_DESKTOP')
    if ($Android) {
        $names += 'QT_DIR_ANDROID_ARM64', 'QT_DIR_ANDROID_X86_64',
                  'ANDROID_SDK_ROOT', 'ANDROID_NDK_ROOT', 'JAVA_HOME'
    }

    Write-Host 'Build environment:' -ForegroundColor Cyan
    foreach ($name in $names) {
        # A build only resolves the kits it needs, so some stay unset.
        $item = Get-Item "env:$name" -ErrorAction SilentlyContinue
        if ($item) { Write-Host ('  {0,-22} {1}' -f $name, $item.Value) }
    }
}
