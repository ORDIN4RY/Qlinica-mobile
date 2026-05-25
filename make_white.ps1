Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_transparent_padded.png")
$out = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height)

for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        if ($p.A -gt 0) {
            # Make the logo pure white but keep the alpha channel
            $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($p.A, 255, 255, 255))
        } else {
            $out.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
        }
    }
}
$out.Save("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_white_padded.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$out.Dispose()
