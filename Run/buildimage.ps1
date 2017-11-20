$BuildingImage = $true

if ("$env:NAVDVDURL" -ne "") {
    (New-Object System.Net.WebClient).DownloadFile("$env:NAVDVDURL", "C:\NAVDVD.zip")
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\NAVDVD.zip","C:\NAVDVD\")
    Remove-Item -Path "C:\NAVDVD.zip" -Force
}
if ("$env:VSIXURL" -ne "") {
    (New-Object System.Net.WebClient).DownloadFile("$env:VSIXURL", ("C:\NAVDVD\"+"$env:VSIXURL".Substring("$env:VSIXURL".LastIndexOf("/")+1)))
}

. (Join-Path $PSScriptRoot "navstart.ps1")

if ("$env:NAVDVDURL" -ne "") {
    while (Test-Path -Path "C:\NAVDVD" -PathType Container) {
        try {
            Remove-Item -Path "C:\NAVDVD" -Force -Recurse
        } catch {
            Start-sleep -Seconds 5
        }
    }
}
$BuildingImage = $false
