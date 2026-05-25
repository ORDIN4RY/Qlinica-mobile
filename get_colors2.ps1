Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\ASUS\Documents\GitHub\sahaduta-mobile\assets\images\app_icon_blue.png")
$dict = @{}
for ($y = 0; $y -lt $bmp.Height; $y += 5) {
    for ($x = 0; $x -lt $bmp.Width; $x += 5) {
        $p = $bmp.GetPixel($x, $y)
        if ($p.A -gt 50) {
            $hex = "#{0:X2}{1:X2}{2:X2}" -f $p.R, $p.G, $p.B
            if ($dict.ContainsKey($hex)) { $dict[$hex]++ } else { $dict[$hex] = 1 }
        }
    }
}
$dict.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
$bmp.Dispose()
