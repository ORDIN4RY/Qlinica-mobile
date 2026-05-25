Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_blue.png")
$out = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height)

for ($y = 0; $y -lt $bmp.Height; $y++) {
    for ($x = 0; $x -lt $bmp.Width; $x++) {
        $p = $bmp.GetPixel($x, $y)
        
        # If color is close to white, make it transparent
        if ($p.R -gt 240 -and $p.G -gt 240 -and $p.B -gt 240) {
            # Map white to transparent
            # Actually, to prevent harsh edges, map alpha based on darkness
            # But simple transparency first:
            $out.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
        } else {
            # For anti-aliased edges (greyish-blueish), we can just keep them as is
            # But wait, if they have white mixed in, they will have a white halo on dark background.
            # A better way to remove white background is to convert brightness to alpha.
            # Let's see: The logo is blue on white. 
            # If we want it to be blue on transparent, we keep the original blue color (say #1565C0), 
            # and set Alpha = 255 - R (since R is high for white, low for blue).
            
            # Since the blue logo has R=21, G=101, B=192
            # White is R=255, G=255, B=255
            # We can compute alpha = (255 - R) * (255 / (255-21)) roughly.
            # Let's just do a simple threshold for now.
            if ($p.R -gt 230 -and $p.G -gt 230 -and $p.B -gt 230) {
                $out.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            } else {
                # To remove white halo, we can forcefully make all pixels pure blue, 
                # but with alpha based on their darkness.
                $darkness = 255 - ($p.R + $p.G + $p.B) / 3
                $alpha = [math]::Min(255, [int]($darkness * 1.5))
                
                $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($alpha, 21, 101, 192))
            }
        }
    }
}
$out.Save("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_blue_transparent.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
$out.Dispose()
