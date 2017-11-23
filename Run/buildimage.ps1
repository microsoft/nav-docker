if ("$env:NAVDVDURL" -ne "") {
    (New-Object System.Net.WebClient).DownloadFile("$env:NAVDVDURL", "C:\NAVDVD.zip")
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\NAVDVD.zip","C:\NAVDVD\")
    Remove-Item -Path "C:\NAVDVD.zip" -Force
}
if ("$env:VSIXURL" -ne "") {
    (New-Object System.Net.WebClient).DownloadFile("$env:VSIXURL", ("C:\NAVDVD\"+"$env:VSIXURL".Substring("$env:VSIXURL".LastIndexOf("/")+1)))
}

$setupVersion = (Get-Item -Path "c:\navdvd\setup.exe").VersionInfo.FileVersion
$versionFolder = $setupVersion.Split('.')[0]+$setupVersion.Split('.')[1]
Copy-Item -Path (Join-Path $PSScriptRoot "Install-$versionFolder\*.*") -Destination $PSScriptRoot -Force

# Remove version specific folders
Remove-Item (Join-Path $PSScriptRoot "Install-90") -Recurse -Force
Remove-Item (Join-Path $PSScriptRoot "Install-100") -Recurse -Force
Remove-Item (Join-Path $PSScriptRoot "Install-110") -Recurse -Force

. (Join-Path $PSScriptRoot "navinstall.ps1")

if ("$env:NAVDVDURL" -ne "") {
    while (Test-Path -Path "C:\NAVDVD" -PathType Container) {
        try {
            Remove-Item -Path "C:\NAVDVD" -Force -Recurse
        } catch {
            Start-sleep -Seconds 5
        }
    }
}

Remove-Item "c:\run\navinstall.ps1" -Force
Remove-Item "c:\run\buildimage.ps1" -Force
