Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
$src = 'C:\Users\wmanda\Downloads\IMG_9966.HEIC'
$dst = 'C:\Users\wmanda\90days-awsdevops\Terraform\IMG_9966-tiny.jpg'
$decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.Uri]$src, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
$frame = $decoder.Frames[0]
$width = 90
$scale = $width / $frame.PixelWidth
$scaled = New-Object System.Windows.Media.Imaging.TransformedBitmap($frame, (New-Object System.Windows.Media.ScaleTransform($scale, $scale)))
$encoder = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
$encoder.QualityLevel = 40
$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($scaled))
$fs = [System.IO.File]::Open($dst, 'Create')
$encoder.Save($fs)
$fs.Close()
Write-Output 'OK'
