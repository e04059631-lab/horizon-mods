# Generates 55 unique, bespoke 256x256 anti-aliased icons for horizon-mods (keeps flagship motion-blur.png)
# Plus renders an 8x7 contact sheet of all 56 icons for visual QA.
param(
    [string]$ContactSheetOut = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent $PSScriptRoot
$IconsDir = Join-Path $Root "icons"
New-Item -ItemType Directory -Path $IconsDir -Force | Out-Null

function New-Color([int]$a, [int]$r, [int]$g, [int]$b) {
    [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}
function Hex-Color([string]$hex, [int]$a = 255) {
    $h = $hex.TrimStart('#')
    $r = [Convert]::ToInt32($h.Substring(0,2), 16)
    $g = [Convert]::ToInt32($h.Substring(2,2), 16)
    $b = [Convert]::ToInt32($h.Substring(4,2), 16)
    [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

function New-RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = [Math]::Min($r * 2, [Math]::Min($w, $h))
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Fill-Circle($g, [float]$cx, [float]$cy, [float]$r, $brush) {
    $g.FillEllipse($brush, $cx - $r, $cy - $r, $r * 2, $r * 2)
}
function Draw-Circle($g, [float]$cx, [float]$cy, [float]$r, $pen) {
    $g.DrawEllipse($pen, $cx - $r, $cy - $r, $r * 2, $r * 2)
}
function Fill-Poly($g, $pts, $brush) {
    $arr = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF($_[0], $_[1]) })
    $g.FillPolygon($brush, $arr)
}
function Draw-Poly($g, $pts, $pen) {
    $arr = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF($_[0], $_[1]) })
    $g.DrawPolygon($pen, $arr)
}
function Draw-Lines($g, $pts, $pen) {
    $arr = [System.Drawing.PointF[]]@($pts | ForEach-Object { New-Object System.Drawing.PointF($_[0], $_[1]) })
    $g.DrawLines($pen, $arr)
}
function New-Pen([string]$hex, [float]$w, [int]$a = 255) {
    $p = New-Object System.Drawing.Pen((Hex-Color $hex $a), $w)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    return $p
}
function New-Brush([string]$hex, [int]$a = 255) {
    New-Object System.Drawing.SolidBrush((Hex-Color $hex $a))
}
function Fill-Glow($g, [float]$cx, [float]$cy, [float]$r, [string]$hex, [int]$alpha = 110) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddEllipse($cx - $r, $cy - $r, $r * 2, $r * 2)
    $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gp)
    $pgb.CenterColor = Hex-Color $hex $alpha
    $pgb.SurroundColors = [System.Drawing.Color[]]@(Hex-Color $hex 0)
    $g.FillPath($pgb, $gp)
    $pgb.Dispose(); $gp.Dispose()
}

function Save-Icon([string]$id, [string]$bg1, [string]$bg2, [string]$glowHex, [scriptblock]$drawFn) {
    $size = 256
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $cardPath = New-RoundedPath 8 8 240 240 52
    $g.SetClip($cardPath)

    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 0)),
        (New-Object System.Drawing.PointF(256, 256)),
        (Hex-Color $bg1),
        (Hex-Color $bg2)
    )
    $g.FillRectangle($bgBrush, 0, 0, 256, 256)
    $bgBrush.Dispose()

    if ($glowHex) {
        Fill-Glow $g 128 118 115 $glowHex 85
    }

    # Subtle top glass sheen
    $sheenBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(0, 8)),
        (New-Object System.Drawing.PointF(0, 128)),
        (New-Color 36 255 255 255),
        (New-Color 0 255 255 255)
    )
    $g.FillRectangle($sheenBrush, 8, 8, 240, 110)
    $sheenBrush.Dispose()

    # Draw bespoke subject
    & $drawFn $g

    $g.ResetClip()

    # Crisp glass rim border
    $rimPen = New-Object System.Drawing.Pen((New-Color 65 255 255 255), 3.0)
    $g.DrawPath($rimPen, $cardPath)
    $rimPen.Dispose()
    $cardPath.Dispose()

    $outPath = Join-Path $IconsDir "$id.png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

# ==============================================================================
# 26 BESPOKE SHADER ICONS (#02..#27; motion-blur.png kept as flagship)
# ==============================================================================

# 02. fullbright — Glowing golden lightbulb with rays
Save-Icon "fullbright" "#1D1A0E" "#0E0D09" "#FFD54F" {
    param($g)
    Fill-Glow $g 128 106 86 "#FFE066" 130
    $rayPen = New-Pen "#FFE082" 7 210
    foreach ($deg in @(-145,-115,-85,-55,-25,205,235)) {
        $rad = $deg * [Math]::PI / 180.0
        $g.DrawLine($rayPen, [float](128 + [Math]::Cos($rad)*66), [float](104 + [Math]::Sin($rad)*66),
                             [float](128 + [Math]::Cos($rad)*86), [float](104 + [Math]::Sin($rad)*86))
    }
    $bulbBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(84, 54)), (New-Object System.Drawing.PointF(172, 160)),
        (Hex-Color "#FFF7C2"), (Hex-Color "#FFB300")
    )
    Fill-Circle $g 128 104 46 $bulbBrush
    $g.FillRectangle($bulbBrush, 106, 134, 44, 24)
    $bulbBrush.Dispose()
    # Filament
    $filPen = New-Pen "#FF6F00" 5
    Draw-Lines $g @(@(116,144),@(118,112),@(128,122),@(138,112),@(140,144)) $filPen
    # Metal screw base
    $baseBrush = New-Brush "#90A4AE"
    $pBase = New-RoundedPath 104 158 48 34 10
    $g.FillPath($baseBrush, $pBase); $pBase.Dispose()
    $ribPen = New-Pen "#546E7A" 4
    $g.DrawLine($ribPen, 106, 169, 150, 169)
    $g.DrawLine($ribPen, 106, 180, 150, 180)
    $cap = New-RoundedPath 114 192 28 12 6
    $g.FillPath((New-Brush "#607D8B"), $cap); $cap.Dispose()
}

# 03. vibrant-vanilla — Isometric 3D Minecraft grass block with tiny sun & flower
Save-Icon "vibrant-vanilla" "#0F2A1E" "#0A1713" "#4ADE80" {
    param($g)
    # Top diamond (grass)
    Fill-Poly $g @(@(128,58),@(200,94),@(128,130),@(56,94)) (New-Brush "#4ADE80")
    # Left face (dirt + grass overhang)
    Fill-Poly $g @(@(56,94),@(128,130),@(128,204),@(56,168)) (New-Brush "#8D5524")
    Fill-Poly $g @(@(56,94),@(128,130),@(128,154),@(106,146),@(92,152),@(74,132),@(56,120)) (New-Brush "#22C55E")
    # Right face (shaded dirt + shaded grass overhang)
    Fill-Poly $g @(@(200,94),@(128,130),@(128,204),@(200,168)) (New-Brush "#6B3E18")
    Fill-Poly $g @(@(200,94),@(128,130),@(128,154),@(148,144),@(168,146),@(184,126),@(200,120)) (New-Brush "#16A34A")
    # Crisp edge highlight
    $pen = New-Pen "#DCFCE7" 3 160
    Draw-Lines $g @(@(56,94),@(128,58),@(200,94),@(128,130),@(56,94)) $pen
    # Little red tulip on top
    $g.DrawLine((New-Pen "#15803D" 5), 128, 92, 128, 66)
    Fill-Circle $g 128 62 9 (New-Brush "#FF5252")
    Fill-Circle $g 128 62 4 (New-Brush "#FFEB3B")
}

# 04. colored-lights — Three luminous overlapping RGB prism orbs
Save-Icon "colored-lights" "#121024" "#090812" "#A855F7" {
    param($g)
    Fill-Glow $g 128 84 68 "#FF4D6D" 160
    Fill-Glow $g 92 152 68 "#00E5FF" 160
    Fill-Glow $g 164 152 68 "#FFB703" 160
    Fill-Circle $g 128 90 36 (New-Brush "#FF4D6D" 190)
    Fill-Circle $g 96 146 36 (New-Brush "#00E5FF" 190)
    Fill-Circle $g 160 146 36 (New-Brush "#FFB703" 190)
    Fill-Circle $g 128 128 18 (New-Brush "#FFFFFF" 225)
}

# 05. water-reflections — Mountain & sun mirrored cleanly across a lake horizon
Save-Icon "water-reflections" "#0B1E38" "#071120" "#38BDF8" {
    param($g)
    # Sky sun
    Fill-Glow $g 166 78 44 "#FDE047" 120
    Fill-Circle $g 166 78 18 (New-Brush "#FEF08A")
    # Upper mountains
    Fill-Poly $g @(@(34,132),@(96,66),@(152,132)) (New-Brush "#38BDF8")
    Fill-Poly $g @(@(96,66),@(116,89),@(96,84),@(82,90)) (New-Brush "#E0F2FE")
    Fill-Poly $g @(@(110,132),@(164,86),@(222,132)) (New-Brush "#0284C7")
    # Water horizon line
    $g.DrawLine((New-Pen "#BAE6FD" 3 220), 30, 134, 226, 134)
    # Mirrored upside-down mountain reflection (translucent + ripples)
    Fill-Poly $g @(@(34,136),@(96,200),@(152,136)) (New-Brush "#38BDF8" 110)
    Fill-Poly $g @(@(110,136),@(164,182),@(222,136)) (New-Brush "#0284C7" 110)
    Fill-Circle $g 166 184 15 (New-Brush "#FEF08A" 120)
    # Water ripple lines
    $ripPen = New-Pen "#E0F2FE" 4 150
    $g.DrawLine($ripPen, 52, 152, 128, 152)
    $g.DrawLine($ripPen, 118, 168, 204, 168)
    $g.DrawLine($ripPen, 68, 186, 174, 186)
}

# 06. real-shadows-lite — Sunlit stone pillar casting a sharp diagonal shadow
Save-Icon "real-shadows-lite" "#1E1B16" "#110F0C" "#F59E0B" {
    param($g)
    # Ground plane
    Fill-Poly $g @(@(26,188),@(128,142),@(230,188),@(128,232)) (New-Brush "#44403C")
    # Crisp cast shadow on ground
    Fill-Poly $g @(@(112,172),@(144,172),@(218,194),@(168,214)) (New-Brush "#0C0A09" 220)
    # Sun in top-left
    Fill-Glow $g 62 64 46 "#FDE047" 140
    Fill-Circle $g 62 64 16 (New-Brush "#FEF08A")
    # 3D Pillar: lit left face + shadowed right face + top
    Fill-Poly $g @(@(96,86),@(122,74),@(148,86),@(122,98)) (New-Brush "#F5F5F4")
    Fill-Poly $g @(@(96,86),@(122,98),@(122,184),@(96,172)) (New-Brush "#E7E5E4")
    Fill-Poly $g @(@(148,86),@(122,98),@(122,184),@(148,172)) (New-Brush "#57534E")
}

# 07. horizon-ultra — Faceted royal diamond prism with radiant golden-cyan beams
Save-Icon "horizon-ultra" "#15122E" "#0A0918" "#38BDF8" {
    param($g)
    Fill-Glow $g 128 128 96 "#38BDF8" 120
    # Radiating beams
    $bPen1 = New-Pen "#FDE047" 5 180
    $bPen2 = New-Pen "#38BDF8" 5 180
    $g.DrawLine($bPen1, 128, 30, 128, 56); $g.DrawLine($bPen1, 128, 200, 128, 226)
    $g.DrawLine($bPen2, 30, 128, 56, 128); $g.DrawLine($bPen2, 200, 128, 226, 128)
    # Faceted diamond
    Fill-Poly $g @(@(86,88),@(170,88),@(196,120),@(128,194),@(60,120)) (New-Brush "#0EA5E9")
    Fill-Poly $g @(@(86,88),@(170,88),@(152,120),@(104,120)) (New-Brush "#BAE6FD")
    Fill-Poly $g @(@(104,120),@(152,120),@(128,194)) (New-Brush "#38BDF8")
    Fill-Poly $g @(@(170,88),@(196,120),@(152,120)) (New-Brush "#FDE047" 220)
    Draw-Poly $g @(@(86,88),@(170,88),@(196,120),@(128,194),@(60,120)) (New-Pen "#FFFFFF" 3.5 210)
}

# 08. fps-sharpness — Sharp focusing diamond eye with crisp high-contrast ticks
Save-Icon "fps-sharpness" "#0D2426" "#081417" "#2DD4BF" {
    param($g)
    # Outer sharpening brackets
    $bp = New-Pen "#5EEAD4" 7
    Draw-Lines $g @(@(48,88),@(48,52),@(84,52)) $bp
    Draw-Lines $g @(@(172,52),@(208,52),@(208,88)) $bp
    Draw-Lines $g @(@(48,168),@(48,204),@(84,204)) $bp
    Draw-Lines $g @(@(172,204),@(208,204),@(208,168)) $bp
    # Sharp faceted triangle (CAS sharpen symbol)
    Fill-Poly $g @(@(128,66),@(182,174),@(74,174)) (New-Brush "#14B8A6")
    Fill-Poly $g @(@(128,66),@(182,174),@(128,144)) (New-Brush "#99F6E4")
    Draw-Poly $g @(@(128,66),@(182,174),@(74,174)) (New-Pen "#FFFFFF" 3.5 220)
    Fill-Circle $g 128 138 11 (New-Brush "#0F172A")
}

# 09. crystal-underwater — Sunbeams + rising underwater air bubbles + coral
Save-Icon "crystal-underwater" "#062B45" "#041628" "#22D3EE" {
    param($g)
    # Caustic light rays from surface
    Fill-Poly $g @(@(60,12),@(104,12),@(136,196),@(96,196)) (New-Brush "#67E8F9" 55)
    Fill-Poly $g @(@(132,12),@(172,12),@(208,196),@(164,196)) (New-Brush "#A5F3FC" 45)
    # Coral silhouette at bottom
    $coral = New-Pen "#FB7185" 10
    Draw-Lines $g @(@(66,220),@(66,178),@(48,158)) $coral
    Draw-Lines $g @(@(66,184),@(86,162)) $coral
    Draw-Lines $g @(@(186,220),@(186,182),@(202,164)) (New-Pen "#34D399" 9)
    # Crystal air bubbles
    foreach ($b in @(@(102,148,26),@(154,110,32),@(114,76,18),@(166,168,14))) {
        Fill-Circle $g $b[0] $b[1] $b[2] (New-Brush "#67E8F9" 70)
        Draw-Circle $g $b[0] $b[1] $b[2] (New-Pen "#CFFAFE" 4 220)
        Fill-Circle $g ($b[0] - $b[2]*0.35) ($b[1] - $b[2]*0.35) ($b[2]*0.22) (New-Brush "#FFFFFF" 220)
    }
}

# 10. clear-nether-end — Split Crimson Nether fortress + Violet End crystal
Save-Icon "clear-nether-end" "#260B1E" "#12091E" "#E879F9" {
    param($g)
    # Left half Nether glow, right half End glow
    Fill-Glow $g 78 128 74 "#EF4444" 120
    Fill-Glow $g 178 128 74 "#C084FC" 120
    # Left: Nether fortress pillar & lava arch
    Fill-Poly $g @(@(40,188),@(40,86),@(114,86),@(114,188),@(94,188),@(94,126),@(60,126),@(60,188)) (New-Brush "#991B1B")
    $g.FillRectangle((New-Brush "#F97316"), 60, 140, 34, 48)
    $g.FillRectangle((New-Brush "#FDE047"), 66, 152, 22, 36)
    # Diagonal divider
    $g.DrawLine((New-Pen "#FFFFFF" 4 190), 128, 42, 128, 214)
    # Right: Floating End Crystal diamond inside frame
    Fill-Poly $g @(@(178,76),@(210,128),@(178,180),@(146,128)) (New-Brush "#D946EF")
    Fill-Poly $g @(@(178,92),@(196,128),@(178,164),@(160,128)) (New-Brush "#FAE8FF")
    Draw-Poly $g @(@(178,66),@(218,128),@(178,190),@(138,128)) (New-Pen "#F0ABFC" 3.5 210)
}

# 11. aurora-starry-sky — Green-violet aurora ribbons over night mountain peaks
Save-Icon "aurora-starry-sky" "#091326" "#050A14" "#34D399" {
    param($g)
    # Stars
    foreach ($st in @(@(52,50,3),@(88,42,4),@(190,46,3),@(212,78,3),@(66,86,2.5),@(154,38,3.5))) {
        Fill-Circle $g $st[0] $st[1] $st[2] (New-Brush "#FFFFFF" 230)
    }
    # Aurora ribbon 1 (green)
    $gp1 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp1.AddBezier(26, 134, 86, 48, 156, 140, 232, 62)
    $g.DrawPath((New-Pen "#34D399" 22 140), $gp1)
    $g.DrawPath((New-Pen "#A7F3D0" 8 220), $gp1)
    $gp1.Dispose()
    # Aurora ribbon 2 (violet)
    $gp2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp2.AddBezier(36, 158, 108, 92, 166, 166, 224, 96)
    $g.DrawPath((New-Pen "#A855F7" 18 130), $gp2)
    $g.DrawPath((New-Pen "#E9D5FF" 6 190), $gp2)
    $gp2.Dispose()
    # Dark mountain silhouettes at bottom
    Fill-Poly $g @(@(16,236),@(78,160),@(146,236)) (New-Brush "#0F172A")
    Fill-Poly $g @(@(112,236),@(182,150),@(244,236)) (New-Brush "#1E293B")
}

# 12. golden-sunset — Layered sunset hills with huge glowing setting sun
Save-Icon "golden-sunset" "#3B1712" "#1A0B14" "#FB923C" {
    param($g)
    Fill-Glow $g 128 132 100 "#F59E0B" 160
    # Big warm sun
    $sunB = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(128, 66)), (New-Object System.Drawing.PointF(128, 178)),
        (Hex-Color "#FEF08A"), (Hex-Color "#F97316")
    )
    Fill-Circle $g 128 124 54 $sunB
    $sunB.Dispose()
    # Horizon stripe cutouts across lower sun
    $g.FillRectangle((New-Brush "#3B1712" 120), 66, 146, 124, 7)
    $g.FillRectangle((New-Brush "#3B1712" 160), 66, 160, 124, 8)
    # Layered dark silhouettes
    Fill-Poly $g @(@(12,240),@(12,174),@(88,154),@(176,184),@(244,162),@(244,240)) (New-Brush "#431407")
    Fill-Poly $g @(@(12,240),@(12,196),@(124,178),@(244,202),@(244,240)) (New-Brush "#1C0B0A")
}

# 13. cinematic-bloom — Anamorphic lens flare streak with soft glowing halo rings
Save-Icon "cinematic-bloom" "#1A1426" "#0D0A14" "#F472B6" {
    param($g)
    Fill-Glow $g 128 128 96 "#F472B6" 140
    # Horizontal anamorphic flare
    $flare = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(24, 128)), (New-Object System.Drawing.PointF(232, 128)),
        (New-Color 0 255 210 240), (New-Color 0 255 210 240)
    )
    $cb = New-Object System.Drawing.Drawing2D.ColorBlend
    $cb.Colors = [System.Drawing.Color[]]@(
        (New-Color 0 244 114 182), (New-Color 220 251 207 232), (New-Color 255 255 255 255),
        (New-Color 220 251 207 232), (New-Color 0 244 114 182)
    )
    $cb.Positions = [float[]]@(0.0, 0.35, 0.5, 0.65, 1.0)
    $flare.InterpolationColors = $cb
    $g.FillRectangle($flare, 20, 114, 216, 28)
    $flare.Dispose()
    # Soft lens rings
    Draw-Circle $g 128 128 54 (New-Pen "#F9A8D4" 4 130)
    Draw-Circle $g 128 128 32 (New-Pen "#FDE68A" 5 180)
    Fill-Circle $g 128 128 18 (New-Brush "#FFFFFF")
    Fill-Circle $g 78 96 10 (New-Brush "#38BDF8" 150)
    Fill-Circle $g 184 162 14 (New-Brush "#FDE047" 130)
}

# 14. anime-cel-shading — Bold comic inked speech/burst star with crisp cel outline
Save-Icon "anime-cel-shading" "#1E1238" "#0E091C" "#FB7185" {
    param($g)
    # 10-point comic action starburst
    $pts = @()
    for ($i = 0; $i -lt 16; $i++) {
        $ang = ($i * 22.5 - 90) * [Math]::PI / 180.0
        $rad = if ($i % 2 -eq 0) { 86 } else { 48 }
        $pts += ,@([float](128 + [Math]::Cos($ang)*$rad), [float](128 + [Math]::Sin($ang)*$rad))
    }
    Fill-Poly $g $pts (New-Brush "#FDE047")
    Draw-Poly $g $pts (New-Pen "#09090B" 8)
    # Inner cel-shaded pink star
    $pts2 = @()
    for ($i = 0; $i -lt 10; $i++) {
        $ang = ($i * 36 - 90) * [Math]::PI / 180.0
        $rad = if ($i % 2 -eq 0) { 46 } else { 22 }
        $pts2 += ,@([float](128 + [Math]::Cos($ang)*$rad), [float](128 + [Math]::Sin($ang)*$rad))
    }
    Fill-Poly $g $pts2 (New-Brush "#FB7185")
    Draw-Poly $g $pts2 (New-Pen "#09090B" 6)
}

# 15. retro-ps1-crt — Classic boxy CRT TV with scanlines & antennas
Save-Icon "retro-ps1-crt" "#1B1626" "#0D0B14" "#818CF8" {
    param($g)
    # Twin V antennas
    $antPen = New-Pen "#CBD5E1" 6
    $g.DrawLine($antPen, 114, 72, 82, 34)
    $g.DrawLine($antPen, 142, 72, 174, 34)
    Fill-Circle $g 82 34 6 (New-Brush "#F472B6")
    Fill-Circle $g 174 34 6 (New-Brush "#38BDF8")
    # TV Chassis
    $tv = New-RoundedPath 44 72 168 134 22
    $g.FillPath((New-Brush "#475569"), $tv)
    $g.DrawPath((New-Pen "#94A3B8" 4), $tv); $tv.Dispose()
    # Glowing CRT glass screen
    $scr = New-RoundedPath 60 88 112 102 14
    $g.FillPath((New-Brush "#1E1B4B"), $scr)
    # Color bars + scanlines
    $g.SetClip($scr)
    $g.FillRectangle((New-Brush "#38BDF8"), 60, 88, 28, 102)
    $g.FillRectangle((New-Brush "#4ADE80"), 88, 88, 28, 102)
    $g.FillRectangle((New-Brush "#FACC15"), 116, 88, 28, 102)
    $g.FillRectangle((New-Brush "#F43F5E"), 144, 88, 28, 102)
    for ($y = 92; $y -lt 190; $y += 8) {
        $g.FillRectangle((New-Color 120 0 0 0 | ForEach-Object { New-Object System.Drawing.SolidBrush($_) }), 60, $y, 112, 3)
    }
    $g.ResetClip()
    $g.DrawPath((New-Pen "#0F172A" 4), $scr); $scr.Dispose()
    # Side dials
    Fill-Circle $g 192 110 9 (New-Brush "#CBD5E1")
    Fill-Circle $g 192 138 9 (New-Brush "#94A3B8")
    $g.FillRectangle((New-Brush "#1E293B"), 182, 162, 20, 22)
}

# 16. horror-fog — Twisted dead tree emerging from eerie mist layers
Save-Icon "horror-fog" "#141A1F" "#090C10" "#94A3B8" {
    param($g)
    # Eerie pale moon behind mist
    Fill-Circle $g 164 76 28 (New-Brush "#CBD5E1" 140)
    # Twisted bare tree silhouette
    $treePen = New-Pen "#0F172A" 12
    $g.DrawLine($treePen, 116, 206, 122, 112)
    $brPen = New-Pen "#0F172A" 7
    Draw-Lines $g @(@(120,148),@(82,118),@(62,92)) $brPen
    Draw-Lines $g @(@(82,118),@(74,132)) (New-Pen "#0F172A" 5)
    Draw-Lines $g @(@(121,126),@(158,100),@(182,76)) $brPen
    Draw-Lines $g @(@(122,112),@(114,76),@(132,56)) (New-Pen "#0F172A" 5)
    # Layered fog ribbons
    $fog1 = New-RoundedPath 24 148 164 22 11; $g.FillPath((New-Brush "#CBD5E1" 145), $fog1); $fog1.Dispose()
    $fog2 = New-RoundedPath 68 176 164 24 12; $g.FillPath((New-Brush "#E2E8F0" 175), $fog2); $fog2.Dispose()
    $fog3 = New-RoundedPath 32 204 192 22 11; $g.FillPath((New-Brush "#94A3B8" 165), $fog3); $fog3.Dispose()
}

# 17. cyberpunk-neon — Synthwave magenta-cyan skyscraper skyline + perspective grid
Save-Icon "cyberpunk-neon" "#19082B" "#090414" "#EC4899" {
    param($g)
    Fill-Glow $g 128 118 86 "#EC4899" 140
    # Neon skyline buildings
    $g.FillRectangle((New-Brush "#0F0720"), 44, 86, 36, 74)
    $g.FillRectangle((New-Brush "#0F0720"), 88, 56, 42, 104)
    $g.FillRectangle((New-Brush "#0F0720"), 138, 74, 34, 86)
    $g.FillRectangle((New-Brush "#0F0720"), 178, 98, 34, 62)
    $g.DrawRectangle((New-Pen "#22D3EE" 3.5), 44, 86, 36, 74)
    $g.DrawRectangle((New-Pen "#EC4899" 3.5), 88, 56, 42, 104)
    $g.DrawRectangle((New-Pen "#22D3EE" 3.5), 138, 74, 34, 86)
    $g.DrawRectangle((New-Pen "#A855F7" 3.5), 178, 98, 34, 62)
    # Neon windows
    for ($y = 70; $y -le 140; $y += 16) {
        $g.FillRectangle((New-Brush "#F472B6"), 98, $y, 22, 6)
    }
    $g.FillRectangle((New-Brush "#22D3EE"), 54, 102, 16, 6)
    $g.FillRectangle((New-Brush "#22D3EE"), 147, 92, 16, 6)
    # Perspective cyber grid below horizon
    $gp = New-Pen "#EC4899" 3 210
    $g.DrawLine((New-Pen "#22D3EE" 4), 20, 160, 236, 160)
    $g.DrawLine($gp, 20, 180, 236, 180)
    $g.DrawLine($gp, 20, 206, 236, 206)
    foreach ($x in @(40, 84, 128, 172, 216)) {
        $g.DrawLine((New-Pen "#22D3EE" 2.5 180), 128 + ($x - 128)*0.45, 160, $x, 234)
    }
}

# 18. no-fog — Crisp pair of binoculars looking into crystal clear distance
Save-Icon "no-fog" "#0B2942" "#071829" "#60A5FA" {
    param($g)
    # Clear distant horizon peaks in background
    Fill-Poly $g @(@(24,186),@(84,126),@(140,186)) (New-Brush "#38BDF8" 70)
    Fill-Poly $g @(@(110,186),@(176,118),@(234,186)) (New-Brush "#60A5FA" 70)
    # Binocular bridge & tubes
    $g.FillRectangle((New-Brush "#334155"), 102, 110, 52, 24)
    $g.FillRectangle((New-Brush "#475569"), 56, 74, 52, 54)
    $g.FillRectangle((New-Brush "#475569"), 148, 74, 52, 54)
    # Dual front lenses
    Fill-Circle $g 82 142 38 (New-Brush "#1E293B")
    Fill-Circle $g 174 142 38 (New-Brush "#1E293B")
    Draw-Circle $g 82 142 38 (New-Pen "#94A3B8" 6)
    Draw-Circle $g 174 142 38 (New-Pen "#94A3B8" 6)
    Fill-Circle $g 82 142 26 (New-Brush "#38BDF8")
    Fill-Circle $g 174 142 26 (New-Brush "#38BDF8")
    # Lens glint
    Fill-Circle $g 73 132 7 (New-Brush "#FFFFFF" 220)
    Fill-Circle $g 165 132 7 (New-Brush "#FFFFFF" 220)
}

# 19. true-darkness — Pitch-black cave tunnel with a single dim glowing eye/ember
Save-Icon "true-darkness" "#0D0E14" "#040407" "#475569" {
    param($g)
    # Rocky cave entrance arch
    Fill-Poly $g @(@(20,236),@(20,56),@(80,36),@(176,36),@(236,56),@(236,236)) (New-Brush "#1E293B")
    # Pitch-black tunnel interior
    $arch = New-Object System.Drawing.Drawing2D.GraphicsPath
    $arch.AddArc(56, 72, 144, 144, 180, 180)
    $arch.AddLine(200, 144, 200, 236)
    $arch.AddLine(200, 236, 56, 236)
    $arch.CloseFigure()
    $g.FillPath((New-Brush "#020204"), $arch)
    $g.DrawPath((New-Pen "#334155" 4), $arch); $arch.Dispose()
    # Two subtle glowing eyes in deep darkness
    Fill-Glow $g 112 146 18 "#F8FAFC" 110
    Fill-Glow $g 144 146 18 "#F8FAFC" 110
    Fill-Circle $g 112 146 5 (New-Brush "#E2E8F0")
    Fill-Circle $g 144 146 5 (New-Brush "#E2E8F0")
}

# 20. warm-torchlight — Detailed Minecraft wooden torch with warm flame & ember halo
Save-Icon "warm-torchlight" "#2B1608" "#140A04" "#FB923C" {
    param($g)
    Fill-Glow $g 128 84 92 "#F97316" 165
    # Wooden stick (pixel-clean)
    $stick = New-RoundedPath 114 114 28 102 6
    $g.FillPath((New-Brush "#92400E"), $stick)
    $g.FillRectangle((New-Brush "#B45309"), 118, 118, 10, 94)
    $g.DrawPath((New-Pen "#451A03" 3), $stick); $stick.Dispose()
    # Charred torch head
    $g.FillRectangle((New-Brush "#292524"), 112, 104, 32, 18)
    # Layered warm flame
    Fill-Poly $g @(@(128,44),@(158,82),@(146,108),@(110,108),@(98,82)) (New-Brush "#F97316")
    Fill-Poly $g @(@(128,58),@(146,86),@(138,108),@(118,108),@(110,86)) (New-Brush "#FACC15")
    Fill-Poly $g @(@(128,74),@(136,92),@(128,106),@(120,92)) (New-Brush "#FEF9C3")
    # Floating sparks
    Fill-Circle $g 94 64 4 (New-Brush "#FDE047")
    Fill-Circle $g 164 58 3.5 (New-Brush "#FB923C")
    Fill-Circle $g 156 84 3 (New-Brush "#FEF08A")
}

# 21. noir-bw — Classic cinema clapperboard / film strip with Sin City crimson heart/accent
Save-Icon "noir-bw" "#18181B" "#09090B" "#71717A" {
    param($g)
    # Film frame strip
    $strip = New-RoundedPath 44 52 168 152 14
    $g.FillPath((New-Brush "#27272A"), $strip)
    $g.DrawPath((New-Pen "#E4E4E7" 4), $strip); $strip.Dispose()
    # Sprocket holes top & bottom
    for ($x = 56; $x -le 188; $x += 24) {
        $g.FillRectangle((New-Brush "#09090B"), $x, 60, 12, 12)
        $g.FillRectangle((New-Brush "#09090B"), $x, 184, 12, 12)
    }
    # High-contrast B&W inner scene
    $g.FillRectangle((New-Brush "#F4F4F5"), 56, 80, 144, 96)
    Fill-Poly $g @(@(56,80),@(128,80),@(100,176),@(56,176)) (New-Brush "#18181B")
    # Sin-City single crimson accent circle
    Fill-Circle $g 144 128 24 (New-Brush "#EF4444")
}

# 22. pastel-dream — Fluffy layered pink-lavender clouds with tiny golden star
Save-Icon "pastel-dream" "#311B42" "#1D1333" "#F9A8D4" {
    param($g)
    Fill-Glow $g 128 112 96 "#F9A8D4" 135
    # Back lavender cloud
    $lav = New-Brush "#DDD6FE" 210
    Fill-Circle $g 96 122 34 $lav; Fill-Circle $g 146 112 40 $lav; Fill-Circle $g 184 128 28 $lav
    $g.FillRectangle($lav, 96, 118, 88, 38)
    # Front cotton-candy pink cloud
    $pink = New-Brush "#FBCFE8"
    Fill-Circle $g 78 156 30 $pink; Fill-Circle $g 118 144 38 $pink; Fill-Circle $g 162 152 32 $pink
    $g.FillRectangle($pink, 78, 152, 84, 34)
    # Dreamy golden star above
    $starPts = @(@(128,50),@(135,68),@(154,72),@(138,83),@(142,100),@(128,90),@(114,100),@(118,83),@(102,72),@(121,68))
    Fill-Poly $g $starPts (New-Brush "#FEF08A")
}

# 23. night-vision-thermal — Tactical NVG goggles with glowing phosphor green + thermal reticle
Save-Icon "night-vision-thermal" "#082012" "#040F09" "#22C55E" {
    param($g)
    Fill-Glow $g 86 132 54 "#22C55E" 140
    Fill-Glow $g 170 132 54 "#22C55E" 140
    # Tactical goggle housing
    $mount = New-RoundedPath 104 72 48 34 8
    $g.FillPath((New-Brush "#334155"), $mount); $mount.Dispose()
    $g.FillRectangle((New-Brush "#1E293B"), 64, 102, 128, 56)
    # Dual glowing phosphor lenses
    Fill-Circle $g 86 134 38 (New-Brush "#052E16")
    Fill-Circle $g 170 134 38 (New-Brush "#052E16")
    Draw-Circle $g 86 134 38 (New-Pen "#475569" 7)
    Draw-Circle $g 170 134 38 (New-Pen "#475569" 7)
    Fill-Circle $g 86 134 26 (New-Brush "#4ADE80")
    Fill-Circle $g 170 134 26 (New-Brush "#4ADE80")
    # Thermal orange hotspot inside right lens
    Fill-Circle $g 170 134 11 (New-Brush "#F97316")
    Fill-Circle $g 170 134 5 (New-Brush "#FEF08A")
    # Reticle in left lens
    $rp = New-Pen "#052E16" 2.5
    $g.DrawLine($rp, 72, 134, 100, 134); $g.DrawLine($rp, 86, 120, 86, 148)
}

# 24. depth-of-field — 6-blade camera aperture iris with soft bokeh backdrop
Save-Icon "depth-of-field" "#121B2E" "#090E1A" "#60A5FA" {
    param($g)
    # Soft background bokeh balls
    Fill-Circle $g 54 66 20 (New-Brush "#38BDF8" 80)
    Fill-Circle $g 202 74 24 (New-Brush "#A855F7" 80)
    Fill-Circle $g 196 196 18 (New-Brush "#F472B6" 80)
    # Camera lens outer ring
    Fill-Circle $g 128 128 72 (New-Brush "#1E293B")
    Draw-Circle $g 128 128 72 (New-Pen "#94A3B8" 6)
    Draw-Circle $g 128 128 56 (New-Pen "#38BDF8" 3 180)
    # 6 iris blades
    $bladePen = New-Pen "#CBD5E1" 4.5
    for ($i = 0; $i -lt 6; $i++) {
        $a1 = ($i * 60) * [Math]::PI / 180.0
        $a2 = (($i * 60) + 78) * [Math]::PI / 180.0
        $g.DrawLine($bladePen, [float](128 + [Math]::Cos($a1)*24), [float](128 + [Math]::Sin($a1)*24),
                               [float](128 + [Math]::Cos($a2)*56), [float](128 + [Math]::Sin($a2)*56))
    }
    Fill-Circle $g 128 128 22 (New-Brush "#0EA5E9")
    Fill-Circle $g 120 120 7 (New-Brush "#E0F2FE" 210)
}

# 25. heat-haze — Desert dune & cactus under scorching sun + wavy heat lines
Save-Icon "heat-haze" "#3B1B0A" "#1C0C05" "#F97316" {
    param($g)
    Fill-Glow $g 176 74 58 "#FACC15" 150
    Fill-Circle $g 176 74 24 (New-Brush "#FEF08A")
    # Wavy rising heat shimmer lines
    $hp = New-Pen "#FDBA74" 5 200
    foreach ($x in @(66, 100, 134)) {
        $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp.AddBezier($x, 120, $x-12, 96, $x+12, 74, $x, 52)
        $g.DrawPath($hp, $gp); $gp.Dispose()
    }
    # Desert dune
    Fill-Poly $g @(@(12,236),@(12,184),@(96,156),@(186,180),@(244,166),@(244,236)) (New-Brush "#D97706")
    # Cactus silhouette
    $cp = New-Pen "#15803D" 14
    $g.DrawLine($cp, 174, 196, 174, 126)
    $cp2 = New-Pen "#16A34A" 10
    Draw-Lines $g @(@(174,166),@(152,166),@(152,144)) $cp2
    Draw-Lines $g @(@(174,154),@(196,154),@(196,134)) $cp2
}

# 26. blood-moon — Giant crimson cratered Blood Moon with bat silhouettes
Save-Icon "blood-moon" "#2E090D" "#140407" "#EF4444" {
    param($g)
    Fill-Glow $g 128 126 104 "#DC2626" 185
    # Crimson moon
    $mB = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF(68, 66)), (New-Object System.Drawing.PointF(188, 186)),
        (Hex-Color "#FCA5A5"), (Hex-Color "#B91C1C")
    )
    Fill-Circle $g 128 128 66 $mB; $mB.Dispose()
    # Craters
    Fill-Circle $g 102 104 14 (New-Brush "#991B1B" 160)
    Fill-Circle $g 152 146 18 (New-Brush "#7F1D1D" 150)
    Fill-Circle $g 144 96 9 (New-Brush "#991B1B" 140)
    Fill-Circle $g 98 152 10 (New-Brush "#7F1D1D" 140)
    # Two flying bat silhouettes
    $bat = New-Brush "#090406"
    Fill-Poly $g @(@(74,118),@(90,108),@(100,116),@(110,108),@(126,118),@(110,118),@(100,124),@(90,118)) $bat
    Fill-Poly $g @(@(146,150),@(158,143),@(165,149),@(172,143),@(184,150),@(172,150),@(165,155),@(158,150)) $bat
}

# 27. pvp-boost-minimal — Speedometer gauge + electric lightning bolt
Save-Icon "pvp-boost-minimal" "#0C2136" "#07101E" "#38BDF8" {
    param($g)
    # Speedometer arc
    $g.DrawArc((New-Pen "#1E3A5F" 14), 48, 56, 160, 160, 150, 240)
    $g.DrawArc((New-Pen "#38BDF8" 14), 48, 56, 160, 160, 150, 185)
    $g.DrawArc((New-Pen "#FACC15" 14), 48, 56, 160, 160, 335, 55)
    # Electric lightning bolt in center
    Fill-Poly $g @(@(140,74),@(96,138),@(126,138),@(114,196),@(164,126),@(134,126)) (New-Brush "#FDE047")
    Draw-Poly $g @(@(140,74),@(96,138),@(126,138),@(114,196),@(164,126),@(134,126)) (New-Pen "#FFFFFF" 3 200)
}

# ==============================================================================
# 29 BESPOKE PVP & QOL RESOURCEPACK ICONS (#28..#56)
# ==============================================================================

# 28. low-fire — Screen frame with flames pushed neatly low at the bottom edge
Save-Icon "low-fire" "#2B1109" "#140704" "#F97316" {
    param($g)
    # Viewport screen frame
    $scr = New-RoundedPath 44 46 168 164 18
    $g.FillPath((New-Brush "#0F172A" 200), $scr)
    $g.SetClip($scr)
    # Downward arrows showing low flame height
    $arrP = New-Pen "#94A3B8" 5 180
    $g.DrawLine($arrP, 128, 72, 128, 122)
    Draw-Lines $g @(@(112,108),@(128,124),@(144,108)) $arrP
    # Low fire tongues along bottom strip only
    Fill-Poly $g @(@(40,214),@(58,162),@(78,188),@(102,150),@(128,184),@(154,148),@(178,186),@(198,160),@(216,214)) (New-Brush "#F97316")
    Fill-Poly $g @(@(48,214),@(70,180),@(96,196),@(126,172),@(156,194),@(184,178),@(208,214)) (New-Brush "#FDE047")
    $g.ResetClip()
    $g.DrawPath((New-Pen "#FB923C" 5), $scr); $scr.Dispose()
}

# 29. no-pumpkin-blur — Carved pumpkin with clean diagonal slash ("No Blur!")
Save-Icon "no-pumpkin-blur" "#2E1708" "#160A04" "#FB923C" {
    param($g)
    # Green stem
    $g.FillRectangle((New-Brush "#22C55E"), 118, 44, 20, 26)
    # Pumpkin body
    $pBody = New-RoundedPath 56 66 144 134 38
    $g.FillPath((New-Brush "#EA580C"), $pBody)
    $g.DrawPath((New-Pen "#FB923C" 4), $pBody); $pBody.Dispose()
    # Carved triangle eyes & jagged grin
    Fill-Poly $g @(@(82,118),@(100,96),@(114,118)) (New-Brush "#FEF08A")
    Fill-Poly $g @(@(142,118),@(156,96),@(174,118)) (New-Brush "#FEF08A")
    Fill-Poly $g @(@(82,148),@(98,164),@(114,150),@(128,166),@(142,150),@(158,164),@(174,148),@(158,176),@(98,176)) (New-Brush "#FEF08A")
    # Crisp red prohibition slash
    Draw-Circle $g 128 128 84 (New-Pen "#EF4444" 10)
    $g.DrawLine((New-Pen "#EF4444" 11), 68, 68, 188, 188)
}

# 30. clear-spyglass — Diagonal copper & amethyst Minecraft spyglass telescope
Save-Icon "clear-spyglass" "#1E1433" "#0E091A" "#C084FC" {
    param($g)
    $g.TranslateTransform(128, 128)
    $g.RotateTransform(-42)
    # Copper eyepiece & main tube
    $t1 = New-RoundedPath -94 -16 64 32 8; $g.FillPath((New-Brush "#B45309"), $t1); $t1.Dispose()
    $t2 = New-RoundedPath -34 -22 72 44 8; $g.FillPath((New-Brush "#D97706"), $t2); $t2.Dispose()
    $t3 = New-RoundedPath 36 -28 46 56 10; $g.FillPath((New-Brush "#F59E0B"), $t3); $t3.Dispose()
    # Metallic band rings
    $g.FillRectangle((New-Brush "#FEF3C7"), -36, -22, 8, 44)
    $g.FillRectangle((New-Brush "#FEF3C7"), 34, -28, 9, 56)
    # Glowing crystal amethyst front lens
    $lens = New-RoundedPath 76 -26 20 52 8
    $g.FillPath((New-Brush "#C084FC"), $lens)
    $g.DrawPath((New-Pen "#F5D0FE" 3), $lens); $lens.Dispose()
    $g.ResetTransform()
    # Lens sparkle
    Fill-Circle $g 188 74 7 (New-Brush "#FFFFFF" 230)
}

# 31. outlined-ores — Stone block with glowing cyan diamond ore + bright neon cyan outline
Save-Icon "outlined-ores" "#0C212E" "#061118" "#22D3EE" {
    param($g)
    $blk = New-RoundedPath 52 52 152 152 18
    $g.FillPath((New-Brush "#475569"), $blk)
    # Stone texture patches
    $g.FillRectangle((New-Brush "#334155"), 64, 68, 44, 28)
    $g.FillRectangle((New-Brush "#64748B"), 132, 138, 52, 32)
    $g.FillRectangle((New-Brush "#334155"), 72, 152, 38, 28)
    # Bright cyan diamond ore chunks
    $dia = New-Brush "#22D3EE"
    $diaHi = New-Brush "#CFFAFE"
    foreach ($ore in @(@(74,80,32,24),@(136,74,36,28),@(104,120,42,30),@(148,154,28,24),@(70,148,26,22))) {
        $r = New-RoundedPath $ore[0] $ore[1] $ore[2] $ore[3] 5
        $g.FillPath($dia, $r); $r.Dispose()
        $g.FillRectangle($diaHi, $ore[0]+4, $ore[1]+4, 10, 6)
    }
    # Signature bright neon outline border
    $g.DrawPath((New-Pen "#67E8F9" 9), $blk); $blk.Dispose()
}

# 32. clear-glass — Crystal-clear glass pane with crisp thin edge & diagonal shine streaks
Save-Icon "clear-glass" "#0C2438" "#081624" "#7DD3FC" {
    param($g)
    $pane = New-RoundedPath 52 52 152 152 16
    $g.FillPath((New-Brush "#E0F2FE" 38), $pane)
    $g.SetClip($pane)
    # Crisp diagonal glass reflections
    $g.DrawLine((New-Pen "#FFFFFF" 14 140), 56, 132, 132, 56)
    $g.DrawLine((New-Pen "#FFFFFF" 6 110), 82, 156, 156, 82)
    $g.DrawLine((New-Pen "#BAE6FD" 10 90), 124, 204, 204, 124)
    $g.ResetClip()
    $g.DrawPath((New-Pen "#BAE6FD" 6), $pane); $pane.Dispose()
}

# 33. short-swords — Compact stubby diamond PvP short-sword
Save-Icon "short-swords" "#0D2433" "#07131C" "#38BDF8" {
    param($g)
    $g.TranslateTransform(128, 132)
    $g.RotateTransform(-45)
    # Short wide diamond blade
    Fill-Poly $g @(@(-16,12),@(-16,-56),@(0,-82),@(16,-56),@(16,12)) (New-Brush "#38BDF8")
    Fill-Poly $g @(@(0,-82),@(16,-56),@(16,12),@(0,12)) (New-Brush "#0284C7")
    Draw-Poly $g @(@(-16,12),@(-16,-56),@(0,-82),@(16,-56),@(16,12)) (New-Pen "#E0F2FE" 3.5)
    # Crossguard
    $cg = New-RoundedPath -38 10 76 16 6
    $g.FillPath((New-Brush "#1E3A5F"), $cg)
    $g.DrawPath((New-Pen "#7DD3FC" 3), $cg); $cg.Dispose()
    # Grip & pommel
    $g.FillRectangle((New-Brush "#92400E"), -9, 26, 18, 34)
    Fill-Circle $g 0 64 13 (New-Brush "#38BDF8")
    $g.ResetTransform()
}

# 34. low-shield — Iron-trimmed wooden shield lowered neatly with downward cue
Save-Icon "low-shield" "#1B2430" "#0D1219" "#94A3B8" {
    param($g)
    # Subtle downward arrow at top
    $ap = New-Pen "#38BDF8" 6
    $g.DrawLine($ap, 128, 42, 128, 76)
    Draw-Lines $g @(@(112,62),@(128,78),@(144,62)) $ap
    # Shield lowered cleanly into bottom half
    $sh = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sh.AddPolygon([System.Drawing.PointF[]]@(
        (New-Object System.Drawing.PointF(72, 96)),
        (New-Object System.Drawing.PointF(184, 96)),
        (New-Object System.Drawing.PointF(184, 162)),
        (New-Object System.Drawing.PointF(128, 214)),
        (New-Object System.Drawing.PointF(72, 162))
    ))
    $g.FillPath((New-Brush "#92400E"), $sh)
    # Wood plank stripe + iron boss
    $g.FillRectangle((New-Brush "#B45309"), 118, 98, 20, 108)
    $g.DrawPath((New-Pen "#CBD5E1" 9), $sh); $sh.Dispose()
    Fill-Circle $g 128 148 14 (New-Brush "#E2E8F0")
}

# 35. dark-glass-ui — Sleek dark frosted UI window card with grid slots
Save-Icon "dark-glass-ui" "#111827" "#060911" "#6366F1" {
    param($g)
    $win = New-RoundedPath 40 52 176 152 20
    $g.FillPath((New-Brush "#1E293B" 230), $win)
    $g.DrawPath((New-Pen "#818CF8" 4 200), $win); $win.Dispose()
    # Window topbar dots
    Fill-Circle $g 64 72 6 (New-Brush "#F87171")
    Fill-Circle $g 84 72 6 (New-Brush "#FBBF24")
    Fill-Circle $g 104 72 6 (New-Brush "#4ADE80")
    $g.DrawLine((New-Pen "#334155" 2.5), 44, 88, 212, 88)
    # Clean dark glass slots
    for ($row = 0; $row -lt 3; $row++) {
        for ($col = 0; $col -lt 4; $col++) {
            $slot = New-RoundedPath (56 + $col * 38) (102 + $row * 30) 30 22 6
            $b = if ($row -eq 0 -and $col -eq 1) { New-Brush "#6366F1" } else { New-Brush "#334155" }
            $g.FillPath($b, $slot); $slot.Dispose()
        }
    }
}

# 36. clean-pvp-crosshair — Precision esports crosshair with center dot & crisp gap
Save-Icon "clean-pvp-crosshair" "#111A24" "#080D14" "#4ADE80" {
    param($g)
    $shadow = New-Pen "#020617" 14
    $main = New-Pen "#4ADE80" 8
    foreach ($seg in @(@(128,48,128,96),@(128,160,128,208),@(48,128,96,128),@(160,128,208,128))) {
        $g.DrawLine($shadow, $seg[0], $seg[1], $seg[2], $seg[3])
        $g.DrawLine($main, $seg[0], $seg[1], $seg[2], $seg[3])
    }
    Fill-Circle $g 128 128 9 (New-Brush "#020617")
    Fill-Circle $g 128 128 5.5 (New-Brush "#FFFFFF")
}

# 37. minimal-weather — Soft cloud with delicate rain streaks & crisp snowflake
Save-Icon "minimal-weather" "#102238" "#091321" "#7DD3FC" {
    param($g)
    $cl = New-Brush "#E2E8F0"
    Fill-Circle $g 88 104 28 $cl; Fill-Circle $g 128 90 36 $cl; Fill-Circle $g 168 104 26 $cl
    $g.FillRectangle($cl, 88, 98, 80, 34)
    # Thin diagonal minimal rain drops
    $rp = New-Pen "#38BDF8" 5
    $g.DrawLine($rp, 80, 148, 70, 178)
    $g.DrawLine($rp, 112, 152, 102, 188)
    $g.DrawLine($rp, 144, 148, 134, 178)
    # Delicate 6-point snowflake on right
    $sp = New-Pen "#BAE6FD" 4
    $g.DrawLine($sp, 178, 154, 178, 194)
    $g.DrawLine($sp, 160, 164, 196, 184)
    $g.DrawLine($sp, 196, 164, 160, 184)
}

# 38. clean-particles — Minimal sparkling geometric diamond bursts
Save-Icon "clean-particles" "#1E1633" "#0F0B1A" "#C084FC" {
    param($g)
    function Draw-Spark($gg, [float]$cx, [float]$cy, [float]$r, [string]$hex) {
        $d = $r * 0.28
        $p = @(
            @($cx, ($cy - $r)),
            @(($cx + $d), ($cy - $d)),
            @(($cx + $r), $cy),
            @(($cx + $d), ($cy + $d)),
            @($cx, ($cy + $r)),
            @(($cx - $d), ($cy + $d)),
            @(($cx - $r), $cy),
            @(($cx - $d), ($cy - $d))
        )
        Fill-Poly $gg $p (New-Brush $hex)
    }
    Draw-Spark $g 128 118 54 "#E9D5FF"
    Draw-Spark $g 74 74 24 "#38BDF8"
    Draw-Spark $g 184 82 20 "#F472B6"
    Draw-Spark $g 178 176 28 "#A78BFA"
    Draw-Spark $g 76 178 18 "#FDE047"
}

# 39. cleaner-hotbar — 5-slot horizontal glass hotbar with neon orange selected slot
Save-Icon "cleaner-hotbar" "#1F1410" "#100A08" "#FF6A1F" {
    param($g)
    $bar = New-RoundedPath 26 98 204 60 14
    $g.FillPath((New-Brush "#18181B" 230), $bar)
    $g.DrawPath((New-Pen "#52525B" 3.5), $bar); $bar.Dispose()
    for ($i = 0; $i -lt 5; $i++) {
        $sx = 34 + $i * 38
        $sl = New-RoundedPath $sx 106 34 44 8
        $g.FillPath((New-Brush "#27272A"), $sl)
        if ($i -eq 2) {
            $g.FillPath((New-Brush "#FF6A1F" 70), $sl)
            $g.DrawPath((New-Pen "#FF6A1F" 5.5), $sl)
        } else {
            $g.DrawPath((New-Pen "#3F3F46" 2), $sl)
        }
        $sl.Dispose()
    }
    # Tiny sword dot in active slot
    Fill-Circle $g 127 128 8 (New-Brush "#FFFFFF")
}

# 40. bright-water-ice — Translucent crystalline ice cube over bright turquoise wave
Save-Icon "bright-water-ice" "#082C38" "#051821" "#22D3EE" {
    param($g)
    # Bright turquoise water base
    $w = New-RoundedPath 28 156 200 62 20
    $g.FillPath((New-Brush "#06B6D4" 180), $w); $w.Dispose()
    # Floating crystal ice cube
    Fill-Poly $g @(@(128,48),@(186,78),@(128,108),@(70,78)) (New-Brush "#ECFEFF" 220)
    Fill-Poly $g @(@(70,78),@(128,108),@(128,170),@(70,140)) (New-Brush "#67E8F9" 190)
    Fill-Poly $g @(@(186,78),@(128,108),@(128,170),@(186,140)) (New-Brush "#22D3EE" 190)
    Draw-Poly $g @(@(128,48),@(186,78),@(186,140),@(128,170),@(70,140),@(70,78)) (New-Pen "#FFFFFF" 4)
    $g.DrawLine((New-Pen "#FFFFFF" 3.5), 128, 108, 128, 170)
}

# 41. compact-totem-hearts — Crisp ruby Minecraft heart + golden heart badge
Save-Icon "compact-totem-hearts" "#2E0C14" "#16060A" "#F43F5E" {
    param($g)
    # Main big crisp red heart
    $hp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $hp.AddBezier(112, 190, 40, 144, 42, 74, 84, 74)
    $hp.AddBezier(84, 74, 104, 74, 112, 92, 112, 98)
    $hp.AddBezier(112, 98, 112, 92, 120, 74, 140, 74)
    $hp.AddBezier(140, 74, 182, 74, 184, 144, 112, 190)
    $g.FillPath((New-Brush "#EF4444"), $hp)
    $g.DrawPath((New-Pen "#450A0A" 5), $hp); $hp.Dispose()
    Fill-Circle $g 86 102 10 (New-Brush "#FCA5A5" 210)
    # Golden absorption mini heart top-right
    $gh = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gh.AddBezier(184, 120, 152, 98, 154, 62, 172, 62)
    $gh.AddBezier(172, 62, 182, 62, 184, 72, 184, 74)
    $gh.AddBezier(184, 74, 184, 72, 186, 62, 196, 62)
    $gh.AddBezier(196, 62, 214, 62, 216, 98, 184, 120)
    $g.FillPath((New-Brush "#FACC15"), $gh)
    $g.DrawPath((New-Pen "#713F12" 4), $gh); $gh.Dispose()
}

# 42. no-screen-borders — Four outward-expanding fullscreen corner arrows
Save-Icon "no-screen-borders" "#132033" "#09101C" "#60A5FA" {
    param($g)
    $p = New-Pen "#60A5FA" 9
    # Top-left outward arrow
    Draw-Lines $g @(@(52,96),@(52,52),@(96,52)) $p; $g.DrawLine($p, 56, 56, 98, 98)
    # Top-right
    Draw-Lines $g @(@(160,52),@(204,52),@(204,96)) $p; $g.DrawLine($p, 200, 56, 158, 98)
    # Bottom-left
    Draw-Lines $g @(@(52,160),@(52,204),@(96,204)) $p; $g.DrawLine($p, 56, 200, 98, 158)
    # Bottom-right
    Draw-Lines $g @(@(160,204),@(204,204),@(204,160)) $p; $g.DrawLine($p, 200, 200, 158, 158)
    # Clear center sparkle
    Fill-Circle $g 128 128 14 (New-Brush "#E0F2FE")
}

# 43. clear-water-overlay — Diving goggles mask with crystal-clear water view
Save-Icon "clear-water-overlay" "#082738" "#04131E" "#38BDF8" {
    param($g)
    # Mask strap
    $g.DrawLine((New-Pen "#0284C7" 14), 28, 124, 228, 124)
    # Diving mask frame
    $mask = New-RoundedPath 44 82 168 92 34
    $g.FillPath((New-Brush "#1E293B"), $mask)
    $g.DrawPath((New-Pen "#38BDF8" 7), $mask); $mask.Dispose()
    # Crystal clear dual-goggle lens
    $lens = New-RoundedPath 58 96 140 64 22
    $g.FillPath((New-Brush "#38BDF8" 160), $lens)
    $g.DrawLine((New-Pen "#FFFFFF" 10 170), 74, 152, 114, 102)
    $g.DrawLine((New-Pen "#FFFFFF" 6 140), 132, 152, 166, 106)
    $lens.Dispose()
    # Nose bridge cutout
    Fill-Poly $g @(@(114,174),@(128,144),@(142,174)) (New-Brush "#1E293B")
}

# 44. bright-crit-particles — Razor-sharp glowing golden-orange critical hit impact burst
Save-Icon "bright-crit-particles" "#2E1C07" "#170D04" "#FACC15" {
    param($g)
    Fill-Glow $g 128 128 96 "#FACC15" 150
    # 6-point sharp kinetic crit star
    $pts = @()
    for ($i = 0; $i -lt 12; $i++) {
        $ang = ($i * 30 - 90) * [Math]::PI / 180.0
        $rad = if ($i % 2 -eq 0) { 86 } else { 28 }
        $pts += ,@([float](128 + [Math]::Cos($ang)*$rad), [float](128 + [Math]::Sin($ang)*$rad))
    }
    Fill-Poly $g $pts (New-Brush "#F59E0B")
    Draw-Poly $g $pts (New-Pen "#FEF08A" 4)
    # Bright white-gold core
    $pts2 = @()
    for ($i = 0; $i -lt 12; $i++) {
        $ang = ($i * 30 - 90) * [Math]::PI / 180.0
        $rad = if ($i % 2 -eq 0) { 48 } else { 15 }
        $pts2 += ,@([float](128 + [Math]::Cos($ang)*$rad), [float](128 + [Math]::Sin($ang)*$rad))
    }
    Fill-Poly $g $pts2 (New-Brush "#FEF9C3")
}

# 45. sticky-piston-marker — Minecraft piston block with bright green slime side stripes
Save-Icon "sticky-piston-marker" "#142616" "#0A140B" "#4ADE80" {
    param($g)
    # Stone piston body
    $body = New-RoundedPath 56 84 144 118 14
    $g.FillPath((New-Brush "#64748B"), $body)
    $g.DrawPath((New-Pen "#334155" 4), $body); $body.Dispose()
    # Wooden top piston head
    $head = New-RoundedPath 52 54 152 38 10
    $g.FillPath((New-Brush "#D97706"), $head)
    $g.DrawPath((New-Pen "#92400E" 4), $head); $head.Dispose()
    # Bright neon green slime coating & side marker arrows!
    $slime = New-RoundedPath 52 46 152 18 8
    $g.FillPath((New-Brush "#4ADE80"), $slime); $slime.Dispose()
    $g.FillRectangle((New-Brush "#22C55E"), 58, 94, 24, 96)
    $g.FillRectangle((New-Brush "#22C55E"), 174, 94, 24, 96)
    # Mechanical piston center rod detail
    $g.FillRectangle((New-Brush "#475569"), 102, 108, 52, 72)
    $g.FillRectangle((New-Brush "#94A3B8"), 114, 120, 28, 48)
}

# 46. redstone-clarity — Observer block face with bold glowing red direction arrow
Save-Icon "redstone-clarity" "#2B0B0E" "#140507" "#EF4444" {
    param($g)
    $obs = New-RoundedPath 48 48 160 160 20
    $g.FillPath((New-Brush "#334155"), $obs)
    $g.DrawPath((New-Pen "#64748B" 5), $obs); $obs.Dispose()
    # Bold glowing crimson direction arrow pointing UP
    Fill-Glow $g 128 128 68 "#EF4444" 130
    Fill-Poly $g @(@(128,68),@(182,126),@(150,126),@(150,188),@(106,188),@(106,126),@(74,126)) (New-Brush "#EF4444")
    Draw-Poly $g @(@(128,68),@(182,126),@(150,126),@(150,188),@(106,188),@(106,126),@(74,126)) (New-Pen "#FCA5A5" 4)
}

# 47. bow-charge-indicator — Drawn curved bow with bright green 100%-charged arrow
Save-Icon "bow-charge-indicator" "#0E2918" "#07140C" "#4ADE80" {
    param($g)
    # Bowstring pulled back to left
    $strP = New-Pen "#E2E8F0" 4.5
    Draw-Lines $g @(@(138,50),@(62,128),@(138,206)) $strP
    # Curved wooden bow limb (warm amber)
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddBezier(138, 50, 206, 86, 206, 170, 138, 206)
    $g.DrawPath((New-Pen "#D97706" 15), $gp)
    $g.DrawPath((New-Pen "#FBBF24" 6), $gp); $gp.Dispose()
    # Drawn arrow shaft + glowing emerald 100% tip
    $g.DrawLine((New-Pen "#FEF3C7" 7), 66, 128, 198, 128)
    Fill-Glow $g 202 128 34 "#4ADE80" 190
    Fill-Poly $g @(@(222,128),@(182,106),@(190,128),@(182,150)) (New-Brush "#4ADE80")
    Draw-Poly $g @(@(222,128),@(182,106),@(190,128),@(182,150)) (New-Pen "#DCFCE7" 3)
}

# 48. crossbow-ready-glow — Loaded crossbow with glowing golden firework bolt
Save-Icon "crossbow-ready-glow" "#2B1908" "#140C04" "#F59E0B" {
    param($g)
    $g.TranslateTransform(128, 128)
    $g.RotateTransform(-35)
    # Crossbow prod (bow arms)
    $prod = New-Object System.Drawing.Drawing2D.GraphicsPath
    $prod.AddBezier(-24, -76, 48, -54, 48, 54, -24, 76)
    $g.DrawPath((New-Pen "#64748B" 12), $prod); $prod.Dispose()
    # Cocked string
    Draw-Lines $g @(@(-24,-76),@(-54,0),@(-24,76)) (New-Pen "#E2E8F0" 4)
    # Wooden stock
    $st = New-RoundedPath -84 -10 132 20 8
    $g.FillPath((New-Brush "#92400E"), $st); $st.Dispose()
    # Loaded glowing golden firework rocket bolt
    $bolt = New-RoundedPath -22 -11 82 22 7
    $g.FillPath((New-Brush "#EF4444"), $bolt); $bolt.Dispose()
    Fill-Poly $g @(@(86,0),@(54,-18),@(54,18)) (New-Brush "#FACC15")
    $g.ResetTransform()
    Fill-Glow $g 180 82 40 "#FDE047" 160
}

# 49. small-totem — Compact golden Totem of Undying with emerald eyes & wings
Save-Icon "small-totem" "#29200A" "#141005" "#FACC15" {
    param($g)
    Fill-Glow $g 128 128 84 "#FACC15" 135
    # Outstretched golden wings
    Fill-Poly $g @(@(44,112),@(92,112),@(92,150),@(54,142)) (New-Brush "#EAB308")
    Fill-Poly $g @(@(212,112),@(164,112),@(164,150),@(202,142)) (New-Brush "#EAB308")
    # Head + torso
    $head = New-RoundedPath 88 60 80 56 14; $g.FillPath((New-Brush "#FACC15"), $head); $head.Dispose()
    $body = New-RoundedPath 94 114 68 82 14; $g.FillPath((New-Brush "#EAB308"), $body); $body.Dispose()
    # Bright emerald eyes
    $g.FillRectangle((New-Brush "#22C55E"), 102, 82, 16, 14)
    $g.FillRectangle((New-Brush "#22C55E"), 138, 82, 16, 14)
    # Golden chest cross trim
    $g.FillRectangle((New-Brush "#FEF08A"), 118, 124, 20, 54)
    $g.FillRectangle((New-Brush "#FEF08A"), 104, 138, 48, 18)
}

# 50. clear-nether-portal — Obsidian portal arch with clean translucent violet swirl
Save-Icon "clear-nether-portal" "#1D0E33" "#0E061A" "#A855F7" {
    param($g)
    # Obsidian outer frame
    $frame = New-RoundedPath 56 40 144 176 14
    $g.FillPath((New-Brush "#1E1B2E"), $frame)
    $g.DrawPath((New-Pen "#4C1D95" 6), $frame); $frame.Dispose()
    # Inner translucent portal glass
    $inner = New-RoundedPath 78 62 100 132 8
    $g.FillPath((New-Brush "#A855F7" 120), $inner)
    $g.SetClip($inner)
    Draw-Circle $g 128 128 42 (New-Pen "#E9D5FF" 5 180)
    Draw-Circle $g 128 128 22 (New-Pen "#F5D0FE" 4 210)
    $g.ResetClip()
    $g.DrawPath((New-Pen "#C084FC" 4), $inner); $inner.Dispose()
}

# 51. clean-enchant-glint — Enchanted book with delicate violet diagonal shimmer
Save-Icon "clean-enchant-glint" "#1E1236" "#0E081C" "#C084FC" {
    param($g)
    # Book cover
    $bk = New-RoundedPath 64 48 128 160 16
    $g.FillPath((New-Brush "#7E22CE"), $bk)
    $g.SetClip($bk)
    # Subtle diagonal enchant shimmer stripes
    $g.DrawLine((New-Pen "#F0ABFC" 18 110), 40, 120, 140, 20)
    $g.DrawLine((New-Pen "#E879F9" 12 95), 90, 220, 210, 100)
    $g.ResetClip()
    $g.DrawPath((New-Pen "#E9D5FF" 4.5), $bk); $bk.Dispose()
    # Spine + gold bookmark ribbon
    $g.FillRectangle((New-Brush "#581C87"), 64, 48, 22, 160)
    $g.FillRectangle((New-Brush "#FACC15"), 118, 48, 22, 74)
    Fill-Poly $g @(@(118,122),@(129,110),@(140,122)) (New-Brush "#7E22CE")
}

# 52. better-bedwars-wool — Vibrant 2x2 BedWars wool blocks (red, blue, yellow, lime)
Save-Icon "better-bedwars-wool" "#1A1B26" "#0E0F17" "#F87171" {
    param($g)
    $tiles = @(
        @(52, 52, "#EF4444", "#FCA5A5"),
        @(134, 52, "#3B82F6", "#93C5FD"),
        @(52, 134, "#FACC15", "#FEF08A"),
        @(134, 134, "#22C55E", "#86EFAC")
    )
    foreach ($t in $tiles) {
        $p = New-RoundedPath $t[0] $t[1] 70 70 14
        $g.FillPath((New-Brush $t[2]), $p)
        $g.DrawPath((New-Pen $t[3] 4.5), $p); $p.Dispose()
        # Subtle woven wool cross-stitch
        $st = New-Pen "#FFFFFF" 3 80
        $g.DrawLine($st, $t[0]+18, $t[1]+26, $t[0]+52, $t[1]+26)
        $g.DrawLine($st, $t[0]+18, $t[1]+44, $t[0]+52, $t[1]+44)
    }
}

# 53. transparent-inventory — Crystal see-through 3x3 translucent inventory grid
Save-Icon "transparent-inventory" "#102030" "#09121C" "#38BDF8" {
    param($g)
    # Background landscape subtly visible THROUGH inventory
    Fill-Poly $g @(@(32,196),@(104,102),@(182,196)) (New-Brush "#22C55E" 95)
    Fill-Circle $g 184 74 20 (New-Brush "#FDE047" 140)
    # Translucent 3x3 slot grid overlay
    for ($r = 0; $r -lt 3; $r++) {
        for ($c = 0; $c -lt 3; $c++) {
            $sl = New-RoundedPath (52 + $c * 52) (52 + $r * 52) 44 44 10
            $g.FillPath((New-Brush "#FFFFFF" 34), $sl)
            $g.DrawPath((New-Pen "#E2E8F0" 3.5 190), $sl); $sl.Dispose()
        }
    }
}

# 54. small-utilities — Compact Golden Apple + glowing Ender Pearl side-by-side
Save-Icon "small-utilities" "#1F1A10" "#0F0D09" "#FACC15" {
    param($g)
    # Left: Compact Golden Apple
    $g.DrawLine((New-Pen "#78350F" 6), 88, 94, 96, 76)
    Fill-Circle $g 78 134 32 (New-Brush "#FACC15")
    Fill-Circle $g 102 134 32 (New-Brush "#EAB308")
    Fill-Circle $g 78 122 9 (New-Brush "#FEF9C3" 220)
    # Right: Compact glowing Ender Pearl
    Fill-Glow $g 174 138 44 "#14B8A6" 150
    Fill-Circle $g 174 138 30 (New-Brush "#0F766E")
    Fill-Circle $g 174 138 19 (New-Brush "#2DD4BF")
    Fill-Circle $g 166 129 7 (New-Brush "#CCFBF1")
}

# 55. clean-sky-celestials — Smooth glowing circular Sun + crisp silver Crescent Moon
Save-Icon "clean-sky-celestials" "#121A36" "#090E21" "#60A5FA" {
    param($g)
    # Left-top: Soft glowing round Sun
    Fill-Glow $g 88 94 56 "#FDE047" 155
    Fill-Circle $g 88 94 31 (New-Brush "#FEF08A")
    # Right-bottom: True vector Crescent Moon (via Region Exclude so zero dark circle artifact!)
    $outerMoon = New-Object System.Drawing.Drawing2D.GraphicsPath
    $outerMoon.AddEllipse(130, 128, 70, 70)
    $cutMoon = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cutMoon.AddEllipse(152, 120, 62, 62)
    $reg = New-Object System.Drawing.Region($outerMoon)
    $reg.Exclude($cutMoon)
    $g.FillRegion((New-Brush "#E2E8F0"), $reg)
    $reg.Dispose(); $outerMoon.Dispose(); $cutMoon.Dispose()
    # Tiny stars
    Fill-Circle $g 178 72 4 (New-Brush "#FFFFFF" 220)
    Fill-Circle $g 62 178 3.5 (New-Brush "#FFFFFF" 190)
    Fill-Circle $g 142 94 2.5 (New-Brush "#BAE6FD" 200)
}

# 56. high-vis-arrows — Neon-cyan Ender Pearl + blazing fiery orange arrow crossing
Save-Icon "high-vis-arrows" "#0C1F2B" "#061018" "#22D3EE" {
    param($g)
    # Blazing fiery orange arrow shooting diagonally top-right
    $g.DrawLine((New-Pen "#FB923C" 11), 56, 196, 186, 66)
    $g.DrawLine((New-Pen "#FEF08A" 4), 60, 192, 184, 68)
    Fill-Poly $g @(@(204,48),@(160,64),@(188,92)) (New-Brush "#F97316")
    # Fletching tail feathers
    $g.DrawLine((New-Pen "#FDE047" 6), 56, 196, 44, 174)
    $g.DrawLine((New-Pen "#FDE047" 6), 56, 196, 78, 208)
    # Neon-cyan glowing Ender Pearl in lower-right foreground
    Fill-Glow $g 164 166 50 "#06B6D4" 180
    Fill-Circle $g 164 166 32 (New-Brush "#0891B2")
    Draw-Circle $g 164 166 32 (New-Pen "#67E8F9" 4.5)
    Fill-Circle $g 164 166 18 (New-Brush "#22D3EE")
    Fill-Circle $g 155 156 7 (New-Brush "#FFFFFF")
}

Write-Host "[OK] Generated 55 unique bespoke icons in $IconsDir (total 56 with motion-blur.png)" -ForegroundColor Green

# Optional: Render an 8x7 contact sheet of all 56 icons for visual inspection
if ($ContactSheetOut) {
    $cat = Get-Content (Join-Path $Root "catalog.json") -Raw | ConvertFrom-Json
    $cols = 8; $rows = 7; $cell = 128; $pad = 12
    $W = $cols * ($cell + $pad) + $pad
    $H = $rows * ($cell + $pad + 22) + $pad
    $sheet = New-Object System.Drawing.Bitmap($W, $H)
    $sg = [System.Drawing.Graphics]::FromImage($sheet)
    $sg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.Clear((Hex-Color "#0F121A"))
    $font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $txtBrush = New-Brush "#CBD5E1"
    $idx = 0
    foreach ($m in $cat.mods) {
        $c = $idx % $cols
        $r = [int][Math]::Floor($idx / $cols)
        $x = $pad + $c * ($cell + $pad)
        $y = $pad + $r * ($cell + $pad + 22)
        $ip = Join-Path $IconsDir "$($m.id).png"
        if (Test-Path $ip) {
            $im = [System.Drawing.Image]::FromFile($ip)
            $sg.DrawImage($im, $x, $y, $cell, $cell)
            $im.Dispose()
        }
        $label = "$($idx+1). $($m.id)"
        if ($label.Length -gt 19) { $label = $label.Substring(0, 18) + "…" }
        $sg.DrawString($label, $font, $txtBrush, $x, $y + $cell + 3)
        $idx++
    }
    $sheet.Save($ContactSheetOut, [System.Drawing.Imaging.ImageFormat]::Png)
    $sg.Dispose(); $sheet.Dispose(); $font.Dispose()
    Write-Host "[OK] Saved 56-icon contact sheet: $ContactSheetOut" -ForegroundColor Cyan
}
