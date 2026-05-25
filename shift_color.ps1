Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon.png")
$out = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height)

for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        if ($p.A -gt 0 -and $p.G -gt $p.R -and $p.B -gt $p.R) {
            $whiteDist = $p.R / 255.0
            $rRatio = 1.05 + (1.0 - 1.05) * $whiteDist
            $gRatio = 0.94 + (1.0 - 0.94) * $whiteDist
            $bRatio = 1.51 + (1.0 - 1.51) * $whiteDist
            
            $nR = [math]::Min(255, [int]($p.R * $rRatio))
            $nG = [math]::Min(255, [int]($p.G * $gRatio))
            $nB = [math]::Min(255, [int]($p.B * $bRatio))
            $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, $nR, $nG, $nB))
        } else {
            $out.SetPixel($x, $y, $p)
        }
    }
}
$out.Save("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_blue.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$out.Dispose()
