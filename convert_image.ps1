Add-Type -AssemblyName System.Windows.Extensions
$src = 'C:\Users\wmanda\Downloads\IMG_9966.HEIC'
$dst = 'C:\Users\wmanda\90days-awsdevops\Terraform\IMG_9966.png'
$decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.Uri]$src, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
$frame = $decoder.Frames[0]
$encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
$encoder.Frames.Add($frame)
$fs = [System.IO.File]::Open($dst, 'Create')
$encoder.Save($fs)
$fs.Close()
Write-Output 'OK'
