<#
.SYNOPSIS
    End-to-end check that a scheduled alarm actually rings.

.DESCRIPTION
    Writes an alarms.json set to fire shortly, launches the app, waits past
    the fire time, and captures the screen. A passing run shows the full-screen
    ringing takeover with Snooze and Dismiss.

    This exercises the whole chain: JSON load -> AlarmScheduler next-fire
    calculation -> timer -> alarmTriggered -> AlarmRingScreen.

    The existing alarms.json is backed up and restored.
#>
[CmdletBinding()]
param(
    [int]$MinutesAhead = 1,
    [string]$Out = "$env:TEMP/flipclock-alarm.png"
)

$ErrorActionPreference = 'Stop'

$dataDir = Join-Path $env:APPDATA 'FlipClock\FlipClock'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
$alarmsPath = Join-Path $dataDir 'alarms.json'
$backupPath = "$alarmsPath.bak"

if (Test-Path $alarmsPath) { Copy-Item $alarmsPath $backupPath -Force }

$fireAt = (Get-Date).AddMinutes($MinutesAhead)
$alarm = @(
    @{
        id            = [guid]::NewGuid().ToString()
        label         = 'Scheduler smoke test'
        hour          = $fireAt.Hour
        minute        = $fireAt.Minute
        repeatDays    = 0
        enabled       = $true
        snoozeMinutes = 5
    }
)
$alarm | ConvertTo-Json -AsArray | Set-Content -Path $alarmsPath -Encoding utf8
Write-Host "Alarm seeded for $($fireAt.ToString('HH:mm')) (now $((Get-Date).ToString('HH:mm:ss')))" -ForegroundColor Cyan

try {
    # Wait until just past the fire time, then give the ring screen a moment.
    $waitSeconds = [int]([Math]::Max(5, ($fireAt.AddSeconds(4) - (Get-Date)).TotalSeconds))
    & "$PSScriptRoot/capture-window.ps1" -Out $Out -DelaySeconds $waitSeconds -Page 2
}
finally {
    if (Test-Path $backupPath) {
        Move-Item $backupPath $alarmsPath -Force
    } else {
        Remove-Item $alarmsPath -ErrorAction SilentlyContinue
    }
}
