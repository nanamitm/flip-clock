<#
.SYNOPSIS
    Screenshots the running app on a connected Android device or emulator.

.DESCRIPTION
    Optionally taps a bottom-navigation entry first, and can rotate the device
    to check the landscape layout. Capture goes via a file on the device and
    `adb pull`, because PowerShell's `>` redirection corrupts the binary stream
    that `adb exec-out screencap` writes.

.EXAMPLE
    ./tools/capture-android.ps1 -Serial emulator-5554 -Page 1 -Out world.png
#>
[CmdletBinding()]
param(
    [string]$Serial = '',
    [string]$Out = "$env:TEMP/flipclock-android.png",

    # 0 = Clock, 1 = World, 2 = Alarm, 3 = Timer, 4 = Stopwatch, 5 = Settings.
    [ValidateRange(0, 5)]
    [int]$Page = 0,

    [ValidateSet('portrait', 'landscape', 'keep')]
    [string]$Orientation = 'keep',

    [int]$DelaySeconds = 2
)

$ErrorActionPreference = 'Stop'
# adb writes routine progress ("1 file pulled") to stderr; under Stop that
# would abort the script.
$PSNativeCommandUseErrorActionPreference = $false
. "$PSScriptRoot/common.ps1"

Resolve-AndroidSdk
$env:PATH = "$env:ANDROID_SDK_ROOT\platform-tools;$env:PATH"
$target = if ($Serial) { @('-s', $Serial) } else { @() }

function Invoke-Adb { & adb @target @args }

if ($Orientation -ne 'keep') {
    # 0 = natural (portrait), 1 = 90 degrees. accelerometer_rotation must be
    # off for user_rotation to take effect.
    Invoke-Adb shell settings put system accelerometer_rotation 0 | Out-Null
    Invoke-Adb shell settings put system user_rotation ($Orientation -eq 'landscape' ? 1 : 0) | Out-Null
    # The activity has to finish its configuration change before taps land on
    # the new layout; two seconds is not always enough.
    Start-Sleep -Seconds 4
}

if ($Page -gt 0) {
    $size = (Invoke-Adb shell wm size) -replace '.*:\s*', ''
    $w, $h = $size.Trim() -split 'x' | ForEach-Object { [int]$_ }
    # Landscape swaps the reported size around, so read it fresh each time.
    if ($Orientation -eq 'landscape' -and $w -lt $h) { $w, $h = $h, $w }

    $x = [int]($w / 6.0 * ($Page + 0.5))
    # Aim at the middle of the navigation bar: closer to the bottom edge the
    # tap lands in the gesture inset, which the app window does not cover.
    $y = [int]($h - 140)
    Invoke-Adb shell input tap $x $y | Out-Null
    Start-Sleep -Milliseconds 700
}

Start-Sleep -Seconds $DelaySeconds

Invoke-Adb shell screencap -p /sdcard/flipclock-shot.png | Out-Null
Invoke-Adb pull /sdcard/flipclock-shot.png $Out | Out-Null
Invoke-Adb shell rm /sdcard/flipclock-shot.png | Out-Null

Write-Host "Saved $Out ($((Get-Item $Out).Length) bytes)" -ForegroundColor Green
