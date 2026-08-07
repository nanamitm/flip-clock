<#
.SYNOPSIS
    Launches the app, screenshots just its window, and shuts it down.

.DESCRIPTION
    Development aid for checking layout and animation without keeping a window
    open by hand. The window is moved to a known position and size, raised to
    the foreground, and only its own rectangle is captured -- nothing else on
    the desktop ends up in the image.

    Qt warnings written to stderr are printed afterwards, since QML binding
    errors only surface at runtime.

.EXAMPLE
    ./tools/capture-window.ps1 -Out shot.png -DelaySeconds 3
#>
[CmdletBinding()]
param(
    [string]$Exe = "$PSScriptRoot/../build/windows-msvc-debug/appFlipClock.exe",
    [string]$Out = "$env:TEMP/flipclock.png",
    [int]$DelaySeconds = 3,
    [int]$Width = 1080,
    [int]$Height = 660,

    # 0 = Clock, 1 = World, 2 = Alarm, 3 = Timer, 4 = Stopwatch, 5 = Settings.
    # Clicks the matching entry in the bottom navigation before capturing.
    [ValidateRange(0, 5)]
    [int]$Page = 0,

    # Extra clicks at window-relative "x,y" coordinates, applied in order after
    # the page switch. Lets a run drive a control before the screenshot.
    [string[]]$ClickAt = @()
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
. "$PSScriptRoot/common.ps1"

# Running straight out of the build tree, so the Qt DLLs have to come from the
# kit rather than from a windeployqt'd folder.
Resolve-QtKits
$env:PATH = "$env:QT_DIR_DESKTOP\bin;$env:PATH"
$env:QT_FORCE_STDERR_LOGGING = '1'

if (-not ('Win32Window' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public class Win32Window {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after,
        int x, int y, int cx, int cy, uint flags);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, IntPtr extra);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static void Click(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(80);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, IntPtr.Zero);
        System.Threading.Thread.Sleep(60);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, IntPtr.Zero);
    }
}
'@
}

$logPath = Join-Path $env:TEMP 'flipclock-stderr.txt'
$proc = Start-Process -FilePath (Resolve-Path $Exe) -PassThru `
    -RedirectStandardError $logPath -RedirectStandardOutput "$logPath.out"

try {
    # Wait for the window to exist before touching it.
    $deadline = (Get-Date).AddSeconds(15)
    while (-not $proc.HasExited -and $proc.MainWindowHandle -eq 0 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
        $proc.Refresh()
    }

    if ($proc.HasExited) {
        Write-Warning "Process exited early with code $($proc.ExitCode)."
        Get-Content $logPath -ErrorAction SilentlyContinue
        return
    }
    if ($proc.MainWindowHandle -eq 0) {
        Write-Warning 'No window appeared within 15 s.'
        return
    }

    $hwnd = $proc.MainWindowHandle
    # HWND_TOPMOST + SWP_SHOWWINDOW. Windows refuses SetForegroundWindow from a
    # background script, so forcing topmost is what actually clears whatever
    # else is on screen out of the capture.
    $topmost = New-Object IntPtr(-1)
    [Win32Window]::SetWindowPos($hwnd, $topmost, 60, 60, $Width, $Height, 0x0040) | Out-Null
    [Win32Window]::SetForegroundWindow($hwnd) | Out-Null

    Start-Sleep -Milliseconds 900

    $rect = New-Object Win32Window+RECT
    [Win32Window]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top

    if ($Page -gt 0) {
        # The navigation bar is 62 px tall and splits the width into six equal
        # cells; click the centre of the requested one.
        $cellWidth = $w / 6.0
        $x = [int]($rect.Left + $cellWidth * ($Page + 0.5))
        $y = [int]($rect.Bottom - 31)
        [Win32Window]::Click($x, $y)
        Start-Sleep -Milliseconds 500
    }

    foreach ($spec in $ClickAt) {
        $parts = $spec -split ','
        if ($parts.Count -ne 2) { throw "ClickAt entry '$spec' is not in 'x,y' form." }
        [Win32Window]::Click($rect.Left + [int]$parts[0], $rect.Top + [int]$parts[1])
        Start-Sleep -Milliseconds 400
    }

    # Let the clock tick a few times so a flip is caught mid-animation.
    Start-Sleep -Seconds $DelaySeconds

    $bitmap = New-Object System.Drawing.Bitmap $w, $h
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0,
        (New-Object System.Drawing.Size $w, $h))
    $bitmap.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "Saved $Out ($w x $h)" -ForegroundColor Green
}
finally {
    if (-not $proc.HasExited) {
        $proc.CloseMainWindow() | Out-Null
        Start-Sleep -Milliseconds 600
        if (-not $proc.HasExited) { $proc.Kill() }
    }
}

Write-Host "`n--- stderr ---" -ForegroundColor Cyan
Get-Content $logPath -ErrorAction SilentlyContinue
