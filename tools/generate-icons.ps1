<#
.SYNOPSIS
    Generates every application icon from a single vector description.

.DESCRIPTION
    The icon is drawn with GDI+ rather than rasterised from an SVG, so nothing
    outside the .NET runtime is needed and the artwork stays reproducible: edit
    the geometry or palette below and re-run.

    Produces:
      assets/icons/appicon.png                     runtime QIcon (256 px)
      assets/icons/appicon.ico                     Windows executable resource
      android/res/mipmap-*/ic_launcher.png         legacy launcher icon
      android/res/mipmap-*/ic_launcher_foreground.png
      android/res/mipmap-*/ic_launcher_background.png
      android/res/mipmap-*/ic_launcher_monochrome.png

    The adaptive-icon XML that ties the three layers together is committed by
    hand at android/res/mipmap-anydpi-v26/ic_launcher.xml.

    Run this after changing the design; the generated files are committed, so a
    normal build does not need it.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------------------
# Palette
#
# Deliberately inverted from the app's Midnight theme: a launcher sits on an
# arbitrary wallpaper, so a dark card on a dark background would disappear.
# A blue field behind a near-white card reads at 48 px and still uses the
# app's accent hue.
# ---------------------------------------------------------------------------
$BackgroundTop = [System.Drawing.Color]::FromArgb(0x35, 0x5C, 0xB8)
$BackgroundBottom = [System.Drawing.Color]::FromArgb(0x16, 0x22, 0x40)
$CardTop = [System.Drawing.Color]::FromArgb(0xFB, 0xFC, 0xFF)
$CardBottom = [System.Drawing.Color]::FromArgb(0xD5, 0xDC, 0xEA)
$DigitColor = [System.Drawing.Color]::FromArgb(0x16, 0x1B, 0x2B)
$FoldColor = [System.Drawing.Color]::FromArgb(0x8E, 0x9A, 0xB4)

$DigitText = '12'

# ---------------------------------------------------------------------------
# Geometry, in fractions of the card's own size
# ---------------------------------------------------------------------------
$CardAspect = 0.78   # height / width
$CornerRatio = 0.16  # corner radius, of card height
$FoldRatio = 0.035   # fold line thickness, of card height
$DigitRatio = 0.56   # digit cap height, of card height

function New-RoundedRectPath {
    param([single]$X, [single]$Y, [single]$W, [single]$H, [single]$Radius)

    $r = [Math]::Min($Radius, [Math]::Min($W, $H) / 2)
    $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($r -le 0) {
        $path.AddRectangle((New-Object System.Drawing.RectangleF $X, $Y, $W, $H))
    } else {
        $path.AddArc($X, $Y, $d, $d, 180, 90)
        $path.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
        $path.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90)
        $path.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
        $path.CloseFigure()
    }
    return $path
}

function Get-IconFontFamily {
    foreach ($name in 'Segoe UI', 'Arial', 'Helvetica') {
        try { return New-Object System.Drawing.FontFamily $name } catch { }
    }
    return [System.Drawing.FontFamily]::GenericSansSerif
}

<#
.SYNOPSIS
    Builds a path for the digits, scaled to an exact height and centred.

.DESCRIPTION
    Measuring the glyph outline and transforming it makes the result
    independent of the font's internal metrics, so swapping the family does not
    silently shift the digits off centre.
#>
function New-DigitPath {
    param([single]$CenterX, [single]$CenterY, [single]$TargetHeight)

    $family = Get-IconFontFamily
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddString($DigitText, $family, [int][System.Drawing.FontStyle]::Bold, 100,
        (New-Object System.Drawing.PointF 0, 0), $format)

    $bounds = $path.GetBounds()
    if ($bounds.Height -le 0) { return $path }

    $scale = $TargetHeight / $bounds.Height
    $matrix = New-Object System.Drawing.Drawing2D.Matrix
    $matrix.Translate($CenterX, $CenterY)
    $matrix.Scale($scale, $scale)
    $matrix.Translate(-($bounds.X + $bounds.Width / 2), -($bounds.Y + $bounds.Height / 2))
    $path.Transform($matrix)

    return $path
}

<#
.SYNOPSIS
    Draws the flip card onto $Graphics.

.PARAMETER Monochrome
    Draws a solid white card with the fold line and digits punched out to
    transparent, which is what Android's themed icons tint.
#>
function Add-FlipCard {
    param(
        [System.Drawing.Graphics]$Graphics,
        [single]$Size,
        [single]$Scale,
        [switch]$Monochrome
    )

    $cardW = $Size * $Scale
    $cardH = $cardW * $CardAspect
    $x = ($Size - $cardW) / 2
    $y = ($Size - $cardH) / 2
    $radius = $cardH * $CornerRatio
    $foldH = [Math]::Max(1.0, $cardH * $FoldRatio)

    $card = New-RoundedRectPath -X $x -Y $y -W $cardW -H $cardH -Radius $radius
    $saved = $Graphics.Save()
    $Graphics.SetClip($card)

    if ($Monochrome) {
        $Graphics.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), $card)
    } else {
        # Two flat halves with a hard break, rather than one gradient: the break
        # is what makes it read as a split-flap rather than a plain tile.
        $upper = New-Object System.Drawing.RectangleF $x, $y, $cardW, ($cardH / 2)
        $lower = New-Object System.Drawing.RectangleF $x, ($y + $cardH / 2), $cardW, ($cardH / 2)
        $Graphics.FillRectangle((New-Object System.Drawing.SolidBrush $CardTop), $upper)
        $Graphics.FillRectangle((New-Object System.Drawing.SolidBrush $CardBottom), $lower)
    }

    # Digits span the fold, so the fold line drawn afterwards splits them.
    $digits = New-DigitPath -CenterX ($Size / 2) -CenterY ($Size / 2) -TargetHeight ($cardH * $DigitRatio)
    $foldRect = New-Object System.Drawing.RectangleF $x, ($y + ($cardH - $foldH) / 2), $cardW, $foldH

    if ($Monochrome) {
        # Punch through to transparency so the launcher's tint shows the shapes.
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $clear = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
        $Graphics.FillPath($clear, $digits)
        $Graphics.FillRectangle($clear, $foldRect)
        $Graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    } else {
        $Graphics.FillPath((New-Object System.Drawing.SolidBrush $DigitColor), $digits)
        $Graphics.FillRectangle((New-Object System.Drawing.SolidBrush $FoldColor), $foldRect)
    }

    $Graphics.Restore($saved)
    $card.Dispose()
    $digits.Dispose()
}

function New-Canvas([int]$Size) {
    $bitmap = New-Object System.Drawing.Bitmap $Size, $Size,
        ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ Bitmap = $bitmap; Graphics = $g }
}

function Add-BackgroundField {
    param([System.Drawing.Graphics]$Graphics, [single]$Size, [System.Drawing.Drawing2D.GraphicsPath]$Clip)

    $saved = $Graphics.Save()
    if ($Clip) { $Graphics.SetClip($Clip) }
    $rect = New-Object System.Drawing.RectangleF 0, 0, $Size, $Size
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect, $BackgroundTop, $BackgroundBottom, 90.0)
    $Graphics.FillRectangle($brush, $rect)
    $brush.Dispose()
    $Graphics.Restore($saved)
}

<#
.SYNOPSIS
    Renders one icon layer.

.PARAMETER Layer
    legacy      - rounded-square background plus the card, for pre-API-26 launchers
    foreground  - card only, sized to survive any adaptive-icon mask
    background  - the blue field, full bleed
    monochrome  - tintable silhouette
#>
function New-IconBitmap {
    param([int]$Size, [ValidateSet('legacy', 'foreground', 'background', 'monochrome')][string]$Layer)

    $canvas = New-Canvas -Size $Size
    $g = $canvas.Graphics

    switch ($Layer) {
        'legacy' {
            $inset = $Size * 0.02
            $shape = New-RoundedRectPath -X $inset -Y $inset `
                -W ($Size - 2 * $inset) -H ($Size - 2 * $inset) -Radius ($Size * 0.22)
            Add-BackgroundField -Graphics $g -Size $Size -Clip $shape
            $shape.Dispose()
            Add-FlipCard -Graphics $g -Size $Size -Scale 0.62
        }
        'background' {
            Add-BackgroundField -Graphics $g -Size $Size -Clip $null
        }
        'foreground' {
            # 0.54 keeps the card's corners inside the circular mask some
            # launchers apply: half its diagonal stays within the 66/108 safe
            # zone that Android guarantees is visible.
            Add-FlipCard -Graphics $g -Size $Size -Scale 0.54
        }
        'monochrome' {
            Add-FlipCard -Graphics $g -Size $Size -Scale 0.54 -Monochrome
        }
    }

    $g.Dispose()
    return $canvas.Bitmap
}

function Save-Png([System.Drawing.Bitmap]$Bitmap, [string]$Path) {
    $dir = Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
}

<#
.SYNOPSIS
    Writes a multi-resolution .ico whose entries are PNG-compressed.

.DESCRIPTION
    GDI+ cannot author .ico files, so the container is assembled by hand.
    PNG-compressed entries are what Windows Vista and later expect for the
    larger sizes, and are accepted at every size.
#>
function Save-Ico([string]$Path, [int[]]$Sizes) {
    $images = @()
    foreach ($size in $Sizes) {
        $bitmap = New-IconBitmap -Size $size -Layer legacy
        $stream = New-Object System.IO.MemoryStream
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $images += , @{ Size = $size; Bytes = $stream.ToArray() }
        $stream.Dispose()
        $bitmap.Dispose()
    }

    $file = [System.IO.File]::Create($Path)
    try {
        $writer = New-Object System.IO.BinaryWriter $file

        $writer.Write([uint16]0)                 # reserved
        $writer.Write([uint16]1)                 # type: icon
        $writer.Write([uint16]$images.Count)

        # Directory entries are fixed width, so every image offset is known
        # before any pixel data is written.
        $offset = 6 + 16 * $images.Count
        foreach ($image in $images) {
            # 0 encodes 256 in the single-byte dimension fields.
            $dimension = if ($image.Size -ge 256) { 0 } else { $image.Size }
            $writer.Write([byte]$dimension)      # width
            $writer.Write([byte]$dimension)      # height
            $writer.Write([byte]0)               # palette size
            $writer.Write([byte]0)               # reserved
            $writer.Write([uint16]1)             # colour planes
            $writer.Write([uint16]32)            # bits per pixel
            $writer.Write([uint32]$image.Bytes.Length)
            $writer.Write([uint32]$offset)
            $offset += $image.Bytes.Length
        }

        foreach ($image in $images) { $writer.Write($image.Bytes) }
        $writer.Flush()
    }
    finally {
        $file.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# Legacy launcher icon, and the 108 dp adaptive layers, per density bucket.
$densities = [ordered]@{
    'mdpi'    = @{ Legacy = 48;  Adaptive = 108 }
    'hdpi'    = @{ Legacy = 72;  Adaptive = 162 }
    'xhdpi'   = @{ Legacy = 96;  Adaptive = 216 }
    'xxhdpi'  = @{ Legacy = 144; Adaptive = 324 }
    'xxxhdpi' = @{ Legacy = 192; Adaptive = 432 }
}

foreach ($density in $densities.Keys) {
    $spec = $densities[$density]
    $dir = Join-Path $repoRoot "android/res/mipmap-$density"

    $layers = [ordered]@{
        'ic_launcher'            = @{ Size = $spec.Legacy;   Layer = 'legacy' }
        'ic_launcher_foreground' = @{ Size = $spec.Adaptive; Layer = 'foreground' }
        'ic_launcher_background' = @{ Size = $spec.Adaptive; Layer = 'background' }
        'ic_launcher_monochrome' = @{ Size = $spec.Adaptive; Layer = 'monochrome' }
    }

    foreach ($name in $layers.Keys) {
        $spec2 = $layers[$name]
        $bitmap = New-IconBitmap -Size $spec2.Size -Layer $spec2.Layer
        Save-Png -Bitmap $bitmap -Path (Join-Path $dir "$name.png")
        $bitmap.Dispose()
    }
    Write-Host "Wrote android/res/mipmap-$density" -ForegroundColor Green
}

$appIconPng = Join-Path $repoRoot 'assets/icons/appicon.png'
$bitmap = New-IconBitmap -Size 256 -Layer legacy
Save-Png -Bitmap $bitmap -Path $appIconPng
$bitmap.Dispose()
Write-Host "Wrote $appIconPng" -ForegroundColor Green

$appIconIco = Join-Path $repoRoot 'assets/icons/appicon.ico'
Save-Ico -Path $appIconIco -Sizes @(16, 24, 32, 48, 64, 128, 256)
Write-Host "Wrote $appIconIco" -ForegroundColor Green
