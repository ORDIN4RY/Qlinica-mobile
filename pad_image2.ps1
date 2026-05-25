Add-Type -AssemblyName System.Drawing
$srcPath = "C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon.png"
$destPath = "C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_padded.png"
$src = [System.Drawing.Image]::FromFile($srcPath)
$newSize = [int][math]::Round([math]::Max($src.Width, $src.Height) * 2.0)
$bmp = New-Object System.Drawing.Bitmap($newSize, $newSize)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Transparent)
$x = [int][math]::Round(($newSize - $src.Width) / 2.0)
$y = [int][math]::Round(($newSize - $src.Height) / 2.0)
$g.DrawImage($src, $x, $y, $src.Width, $src.Height)
$bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
$src.Dispose()
