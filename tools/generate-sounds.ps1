<#
.SYNOPSIS
    Generates the alarm and timer alert tones under assets/sounds.

.DESCRIPTION
    The alert tones are synthesised rather than shipped as opaque binaries, so
    they carry no third-party licensing and can be re-tuned by editing the beep
    patterns below. Both files are seamless loops: 44.1 kHz, 16-bit mono PCM.

    Run this once after checkout; the .wav files are committed, so a normal
    build does not need it.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$sampleRate = 44100
$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets/sounds'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Renders a list of tones into 16-bit PCM samples.
# Each tone is @{ Freq = <Hz, 0 for silence>; Ms = <duration> }.
function New-Samples([object[]]$tones) {
    $samples = [System.Collections.Generic.List[int16]]::new()
    foreach ($tone in $tones) {
        $count = [int]($sampleRate * $tone.Ms / 1000)
        # 8 ms raised-cosine fade at both ends: without it every beep edge is a
        # click, which is far more unpleasant than the tone itself.
        $fade = [Math]::Min([int]($sampleRate * 0.008), [int]($count / 2))
        for ($i = 0; $i -lt $count; $i++) {
            if ($tone.Freq -le 0) { $samples.Add([int16]0); continue }

            $envelope = 1.0
            if ($i -lt $fade) { $envelope = 0.5 - 0.5 * [Math]::Cos([Math]::PI * $i / $fade) }
            elseif ($i -ge ($count - $fade)) {
                $envelope = 0.5 - 0.5 * [Math]::Cos([Math]::PI * ($count - $i) / $fade)
            }

            $angle = 2.0 * [Math]::PI * $tone.Freq * $i / $sampleRate
            # A little second harmonic gives the tone some body.
            $value = [Math]::Sin($angle) * 0.8 + [Math]::Sin($angle * 2) * 0.2
            $samples.Add([int16]([Math]::Round($value * $envelope * 11000)))
        }
    }
    return $samples
}

function Write-Wav([string]$path, [System.Collections.Generic.List[int16]]$samples) {
    $dataBytes = $samples.Count * 2
    $stream = [System.IO.File]::Create($path)
    try {
        $writer = [System.IO.BinaryWriter]::new($stream)

        $writer.Write([char[]]'RIFF')
        $writer.Write([uint32](36 + $dataBytes))
        $writer.Write([char[]]'WAVE')

        $writer.Write([char[]]'fmt ')
        $writer.Write([uint32]16)          # chunk size
        $writer.Write([uint16]1)           # PCM
        $writer.Write([uint16]1)           # mono
        $writer.Write([uint32]$sampleRate)
        $writer.Write([uint32]($sampleRate * 2))  # byte rate
        $writer.Write([uint16]2)           # block align
        $writer.Write([uint16]16)          # bits per sample

        $writer.Write([char[]]'data')
        $writer.Write([uint32]$dataBytes)
        foreach ($s in $samples) { $writer.Write($s) }

        $writer.Flush()
    }
    finally {
        $stream.Dispose()
    }
    Write-Host "Wrote $path ($([Math]::Round($dataBytes / 1KB)) KB)" -ForegroundColor Green
}

# Alarm: an insistent four-pulse burst followed by a pause, so it nags without
# being a continuous drone.
$alarm = New-Samples @(
    @{ Freq = 880; Ms = 130 }, @{ Freq = 0; Ms = 90 }
    @{ Freq = 880; Ms = 130 }, @{ Freq = 0; Ms = 90 }
    @{ Freq = 880; Ms = 130 }, @{ Freq = 0; Ms = 90 }
    @{ Freq = 880; Ms = 130 }, @{ Freq = 0; Ms = 1100 }
)
Write-Wav (Join-Path $outDir 'alarm.wav') $alarm

# Timer: a gentler rising three-note chime -- it marks a finished countdown
# rather than trying to wake anybody up.
$timer = New-Samples @(
    @{ Freq = 660; Ms = 160 }, @{ Freq = 0; Ms = 60 }
    @{ Freq = 880; Ms = 160 }, @{ Freq = 0; Ms = 60 }
    @{ Freq = 1175; Ms = 260 }, @{ Freq = 0; Ms = 900 }
)
Write-Wav (Join-Path $outDir 'timer.wav') $timer
