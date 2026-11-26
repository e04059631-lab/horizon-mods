Add-Type -AssemblyName System.Drawing

$iconsDir = "C:\Users\wwerz\projects\horizon-mods\icons"
New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null

function New-Color([int]$a, [int]$r, [int]$g, [int]$b) {
    return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-RoundedRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2.0
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-ModIcon(
    [string]$id,
    [string]$shape,
    [int[]]$c1,
    [int[]]$c2
) {
    $bmp = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear((New-Color 0 0 0 0))

    $col1 = New-Color 255 $c1[0] $c1[1] $c1[2]
    $col2 = New-Color 255 $c2[0] $c2[1] $c2[2]

    # 1. iOS 26 Liquid Glass Squircle Base
    $card = New-RoundedRect 10 10 236 236 56
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(10, 10)),
        (New-Object System.Drawing.PointF(246, 246)),
        (New-Color 255 20 24 36),
        (New-Color 255 10 12 20)
    )
    $g.FillPath($bgBrush, $card)

    # Clip inside squircle for ambient glows
    $g.SetClip($card)

    # Ambient duo-tone glow orbs
    $orb1 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $orb1.AddEllipse(-20, -20, 200, 200)
    $pgb1 = New-Object System.Drawing.Drawing2D.PathGradientBrush($orb1)
    $pgb1.CenterColor = New-Color 95 $c1[0] $c1[1] $c1[2]
    $pgb1.SurroundColors = @((New-Color 0 $c1[0] $c1[1] $c1[2]))
    $g.FillPath($pgb1, $orb1)

    $orb2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $orb2.AddEllipse(76, 76, 200, 200)
    $pgb2 = New-Object System.Drawing.Drawing2D.PathGradientBrush($orb2)
    $pgb2.CenterColor = New-Color 95 $c2[0] $c2[1] $c2[2]
    $pgb2.SurroundColors = @((New-Color 0 $c2[0] $c2[1] $c2[2]))
    $g.FillPath($pgb2, $orb2)

    # Soft center halo behind symbol
    $halo = New-Object System.Drawing.Drawing2D.GraphicsPath
    $halo.AddEllipse(48, 48, 160, 160)
    $hgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($halo)
    $hgb.CenterColor = New-Color 115 $c1[0] $c1[1] $c1[2]
    $hgb.SurroundColors = @((New-Color 0 $c2[0] $c2[1] $c2[2]))
    $g.FillPath($hgb, $halo)

    # Top glass specular sheen
    $sheenBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(128, 10)),
        (New-Object System.Drawing.PointF(128, 115)),
        (New-Color 46 255 255 255),
        (New-Color 0 255 255 255)
    )
    $g.FillRectangle($sheenBrush, 10, 10, 236, 105)

    # Main symbol gradient brush & pens
    $symBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(56, 56)),
        (New-Object System.Drawing.PointF(200, 200)),
        $col1,
        $col2
    )
    $whitePen = New-Object System.Drawing.Pen((New-Color 235 255 255 255), 8.0)
    $whitePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $whitePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    $gradPen = New-Object System.Drawing.Pen($symBrush, 12.0)
    $gradPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $gradPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $gradPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

    switch ($shape) {
        "sun" {
            $g.FillEllipse($symBrush, 86, 86, 84, 84)
            for ($k = 0; $k -lt 8; $k++) {
                $a = $k * [Math]::PI / 4.0
                $x1 = 128 + [Math]::Cos($a) * 56
                $y1 = 128 + [Math]::Sin($a) * 56
                $x2 = 128 + [Math]::Cos($a) * 78
                $y2 = 128 + [Math]::Sin($a) * 78
                $g.DrawLine($gradPen, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
            }
            $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 190 255 255 255)), 102, 102, 52, 52)
        }
        "moon" {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.FillMode = [System.Drawing.Drawing2D.FillMode]::Alternate
            $p.AddEllipse(68, 64, 124, 124)
            $p.AddEllipse(102, 52, 112, 112)
            $g.FillPath($symBrush, $p)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 220 255 255 255)), 156, 82, 12, 12)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 180 255 255 255)), 176, 114, 8, 8)
        }
        "cube" {
            $top = @(
                (New-Object System.Drawing.PointF(128, 58)),
                (New-Object System.Drawing.PointF(188, 92)),
                (New-Object System.Drawing.PointF(128, 126)),
                (New-Object System.Drawing.PointF(68, 92))
            )
            $left = @(
                (New-Object System.Drawing.PointF(68, 92)),
                (New-Object System.Drawing.PointF(128, 126)),
                (New-Object System.Drawing.PointF(128, 196)),
                (New-Object System.Drawing.PointF(68, 162))
            )
            $right = @(
                (New-Object System.Drawing.PointF(128, 126)),
                (New-Object System.Drawing.PointF(188, 92)),
                (New-Object System.Drawing.PointF(188, 162)),
                (New-Object System.Drawing.PointF(128, 196))
            )
            $g.FillPolygon((New-Object System.Drawing.SolidBrush (New-Color 245 $c1[0] $c1[1] $c1[2])), $top)
            $g.FillPolygon((New-Object System.Drawing.SolidBrush (New-Color 210 $c2[0] $c2[1] $c2[2])), $left)
            $g.FillPolygon((New-Object System.Drawing.SolidBrush (New-Color 155 $c2[0] $c2[1] $c2[2])), $right)
            $thinW = New-Object System.Drawing.Pen((New-Color 210 255 255 255), 4.0)
            $g.DrawPolygon($thinW, $top)
            $g.DrawPolygon($thinW, $left)
            $g.DrawPolygon($thinW, $right)
        }
        "waves" {
            for ($row = 0; $row -lt 3; $row++) {
                $yy = 92 + $row * 34
                $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
                for ($x = 58; $x -le 198; $x += 10) {
                    $wy = $yy + [Math]::Sin(($x - 58) * 0.065 + $row * 1.1) * 11.0
                    $pts.Add((New-Object System.Drawing.PointF([float]$x, [float]$wy)))
                }
                $g.DrawCurve($gradPen, $pts.ToArray(), 0.5)
            }
        }
        "crosshair" {
            $g.DrawEllipse($gradPen, 76, 76, 104, 104)
            $g.DrawLine($whitePen, 128, 54, 128, 92)
            $g.DrawLine($whitePen, 128, 164, 128, 202)
            $g.DrawLine($whitePen, 54, 128, 92, 128)
            $g.DrawLine($whitePen, 164, 128, 202, 128)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush $col1), 118, 118, 20, 20)
        }
        "sparkle" {
            $pts = @(
                (New-Object System.Drawing.PointF(128, 52)),
                (New-Object System.Drawing.PointF(146, 110)),
                (New-Object System.Drawing.PointF(204, 128)),
                (New-Object System.Drawing.PointF(146, 146)),
                (New-Object System.Drawing.PointF(128, 204)),
                (New-Object System.Drawing.PointF(110, 146)),
                (New-Object System.Drawing.PointF(52, 128)),
                (New-Object System.Drawing.PointF(110, 110))
            )
            $g.FillPolygon($symBrush, $pts)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 225 255 255 255)), 114, 114, 28, 28)
        }
        "flame" {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddBezier(128, 52, 188, 98, 192, 166, 128, 202)
            $p.AddBezier(128, 202, 64, 166, 68, 98, 128, 52)
            $g.FillPath($symBrush, $p)
            $inner = New-Object System.Drawing.Drawing2D.GraphicsPath
            $inner.AddBezier(128, 108, 158, 134, 158, 174, 128, 194)
            $inner.AddBezier(128, 194, 98, 174, 98, 134, 128, 108)
            $g.FillPath((New-Object System.Drawing.SolidBrush (New-Color 225 255 245 190)), $inner)
        }
        "sword" {
            $blade = @(
                (New-Object System.Drawing.PointF(188, 68)),
                (New-Object System.Drawing.PointF(192, 92)),
                (New-Object System.Drawing.PointF(118, 166)),
                (New-Object System.Drawing.PointF(90, 138)),
                (New-Object System.Drawing.PointF(164, 64))
            )
            $g.FillPolygon($symBrush, $blade)
            $g.DrawLine($whitePen, 78, 122, 134, 178)
            $g.DrawLine($gradPen, 68, 188, 98, 158)
        }
        "shield" {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddPolygon(@(
                (New-Object System.Drawing.PointF(128, 56)),
                (New-Object System.Drawing.PointF(188, 78)),
                (New-Object System.Drawing.PointF(178, 146)),
                (New-Object System.Drawing.PointF(128, 200)),
                (New-Object System.Drawing.PointF(78, 146)),
                (New-Object System.Drawing.PointF(68, 78))
            ))
            $g.FillPath($symBrush, $p)
            $g.DrawPath($whitePen, $p)
        }
        "eye" {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddBezier(52, 128, 92, 74, 164, 74, 204, 128)
            $p.AddBezier(204, 128, 164, 182, 92, 182, 52, 128)
            $g.DrawPath($gradPen, $p)
            $g.FillEllipse($symBrush, 102, 102, 52, 52)
            $g.FillEllipse((New-Object System.Drawing.SolidBrush (New-Color 240 255 255 255)), 118, 114, 16, 16)
        }
        "bow" {
            $g.DrawArc($gradPen, 68, 62, 120, 132, -70, 140)
            $g.DrawLine($whitePen, 150, 66, 150, 190)
            $g.DrawLine($whitePen, 82, 128, 196, 128)
            $g.DrawLine($gradPen, 174, 108, 198, 128)
            $g.DrawLine($gradPen, 174, 148, 198, 128)
        }
        "heart" {
            $p = New-Object System.Drawing.Drawing2D.GraphicsPath
            $p.AddBezier(128, 194, 54, 146, 58, 74, 98, 74)
            $p.AddBezier(98, 74, 118, 74, 128, 92, 128, 98)
            $p.AddBezier(128, 98, 128, 92, 138, 74, 158, 74)
            $p.AddBezier(158, 74, 198, 74, 202, 146, 128, 194)
            $g.FillPath($symBrush, $p)
            $g.DrawPath((New-Object System.Drawing.Pen((New-Color 180 255 255 255), 4.0)), $p)
        }
        "grid" {
            $r1 = New-RoundedRect 64 64 56 56 14
            $r2 = New-RoundedRect 136 64 56 56 14
            $r3 = New-RoundedRect 64 136 56 56 14
            $r4 = New-RoundedRect 136 136 56 56 14
            $g.FillPath($symBrush, $r1)
            $g.DrawPath($whitePen, $r2)
            $g.DrawPath($whitePen, $r3)
            $g.FillPath($symBrush, $r4)
        }
        "portal" {
            $outer = New-RoundedRect 74 56 108 144 26
            $g.DrawPath($gradPen, $outer)
            $inner = New-RoundedRect 94 76 68 104 18
            $g.FillPath((New-Object System.Drawing.SolidBrush (New-Color 145 $c1[0] $c1[1] $c1[2])), $inner)
            $g.DrawEllipse($whitePen, 108, 104, 40, 48)
        }
        "bolt" {
            $pts = @(
                (New-Object System.Drawing.PointF(142, 54)),
                (New-Object System.Drawing.PointF(82, 136)),
                (New-Object System.Drawing.PointF(126, 136)),
                (New-Object System.Drawing.PointF(112, 202)),
                (New-Object System.Drawing.PointF(174, 118)),
                (New-Object System.Drawing.PointF(130, 118))
            )
            $g.FillPolygon($symBrush, $pts)
        }
        "screen" {
            $r = New-RoundedRect 58 72 140 112 22
            $g.DrawPath($gradPen, $r)
            $g.DrawLine($whitePen, 82, 104, 174, 104)
            $g.DrawLine($whitePen, 82, 128, 152, 128)
            $g.DrawLine($whitePen, 82, 152, 166, 152)
        }
    }

    $g.ResetClip()

    # Crisp glass rim border
    $rimPen = New-Object System.Drawing.Pen((New-Color 70 255 255 255), 2.5)
    $g.DrawPath($rimPen, $card)

    $bmp.Save("$iconsDir\$id.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

$specs = @(
    # 26 Shaders
    @("fullbright",          "sun",       @(255, 214, 64),  @(255, 142, 36)),
    @("vibrant-vanilla",     "sun",       @(255, 168, 52),  @(56, 208, 255)),
    @("colored-lights",      "sparkle",   @(255, 124, 56),  @(64, 224, 255)),
    @("water-reflections",   "waves",     @(56, 212, 255),  @(52, 110, 255)),
    @("real-shadows-lite",   "cube",      @(255, 190, 92),  @(94, 108, 168)),
    @("horizon-ultra",       "sparkle",   @(255, 148, 52),  @(168, 85, 247)),
    @("fps-sharpness",       "crosshair", @(72, 238, 168),  @(36, 168, 255)),
    @("crystal-underwater",  "waves",     @(42, 245, 220),  @(28, 148, 255)),
    @("clear-nether-end",    "portal",    @(255, 104, 64),  @(186, 85, 255)),
    @("aurora-starry-sky",   "moon",      @(52, 245, 168),  @(148, 82, 255)),
    @("golden-sunset",       "sun",       @(255, 186, 68),  @(244, 72, 118)),
    @("cinematic-bloom",     "sparkle",   @(255, 224, 112), @(255, 118, 182)),
    @("anime-cel-shading",   "cube",      @(255, 102, 168), @(82, 208, 255)),
    @("retro-ps1-crt",       "screen",    @(92, 242, 142),  @(58, 152, 255)),
    @("horror-fog",          "eye",       @(138, 156, 174), @(64, 78, 96)),
    @("cyberpunk-neon",      "bolt",      @(255, 48, 182),  @(36, 232, 255)),
    @("no-fog",              "eye",       @(108, 228, 255), @(68, 142, 255)),
    @("true-darkness",       "moon",      @(118, 104, 225), @(38, 44, 88)),
    @("warm-torchlight",     "flame",     @(255, 196, 72),  @(255, 98, 32)),
    @("noir-bw",             "screen",    @(235, 238, 245), @(235, 48, 64)),
    @("pastel-dream",        "sparkle",   @(255, 176, 212), @(162, 208, 255)),
    @("night-vision-thermal","eye",       @(72, 255, 118),  @(255, 112, 36)),
    @("depth-of-field",      "eye",       @(255, 178, 92),  @(122, 118, 255)),
    @("heat-haze",           "flame",     @(255, 152, 48),  @(255, 64, 64)),
    @("blood-moon",          "moon",      @(255, 58, 72),   @(142, 18, 42)),
    @("pvp-boost-minimal",   "bolt",      @(255, 168, 42),  @(52, 224, 148)),

    # 24 Resourcepacks
    @("low-fire",            "flame",     @(255, 138, 36),  @(255, 56, 48)),
    @("no-pumpkin-blur",     "eye",       @(255, 158, 44),  @(198, 92, 28)),
    @("clear-spyglass",      "crosshair", @(255, 212, 88),  @(72, 198, 255)),
    @("outlined-ores",       "cube",      @(52, 238, 255),  @(52, 242, 132)),
    @("clear-glass",         "grid",      @(168, 238, 255), @(92, 168, 255)),
    @("short-swords",        "sword",     @(64, 238, 255),  @(128, 108, 255)),
    @("low-shield",          "shield",    @(255, 186, 72),  @(142, 156, 184)),
    @("dark-glass-ui",       "grid",      @(118, 138, 255), @(58, 68, 108)),
    @("clean-pvp-crosshair", "crosshair", @(255, 255, 255), @(72, 214, 255)),
    @("minimal-weather",     "waves",     @(132, 208, 255), @(98, 128, 198)),
    @("clean-particles",     "sparkle",   @(142, 242, 255), @(188, 132, 255)),
    @("cleaner-hotbar",      "screen",    @(72, 214, 255),  @(255, 142, 56)),
    @("bright-water-ice",    "waves",     @(112, 245, 255), @(58, 158, 255)),
    @("compact-totem-hearts","heart",     @(255, 64, 92),   @(255, 204, 56)),
    @("no-screen-borders",   "screen",    @(148, 228, 255), @(92, 238, 182)),
    @("clear-water-overlay", "waves",     @(64, 228, 255),  @(38, 122, 238)),
    @("bright-crit-particles","sparkle",  @(255, 112, 48),  @(48, 232, 255)),
    @("sticky-piston-marker","cube",      @(132, 238, 78),  @(72, 168, 52)),
    @("redstone-clarity",    "bolt",      @(255, 58, 58),   @(255, 148, 48)),
    @("bow-charge-indicator","bow",       @(64, 245, 118),  @(255, 188, 48)),
    @("crossbow-ready-glow", "bow",       @(58, 242, 196),  @(242, 88, 238)),
    @("small-totem",         "shield",    @(255, 218, 72),  @(64, 232, 148)),
    @("clear-nether-portal", "portal",    @(198, 88, 255),  @(112, 52, 235)),
    @("clean-enchant-glint", "sparkle",   @(192, 132, 255), @(98, 212, 255))
)

foreach ($s in $specs) {
    Draw-ModIcon -id $s[0] -shape $s[1] -c1 $s[2] -c2 $s[3]
}
Write-Host "[OK] Generated $($specs.Count) custom 256x256 Liquid Glass icons!"
