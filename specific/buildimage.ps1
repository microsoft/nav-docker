Write-Host "NAVDVDURL $env:NAVDVDURL"

if ("$env:NAVDVDURL" -ne "") {
    Write-Host "Downloading NAVDVD"
    (New-Object System.Net.WebClient).DownloadFile("$env:NAVDVDURL", "C:\NAVDVD.zip")
    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\NAVDVD.zip","C:\NAVDVD\")
    Remove-Item -Path "C:\NAVDVD.zip" -Force
}
if ("$env:VSIXURL" -ne "") {
    Write-Host "Downloading VSIX"
    (New-Object System.Net.WebClient).DownloadFile("$env:VSIXURL", ("C:\NAVDVD\"+"$env:VSIXURL".Substring("$env:VSIXURL".LastIndexOf("/")+1)))
}

$setupVersion = (Get-Item -Path "c:\navdvd\setup.exe").VersionInfo.FileVersion
$versionNo = [Int]::Parse($setupVersion.Split('.')[0]+$setupVersion.Split('.')[1])
$versionFolder = ""
Get-ChildItem -Path $PSScriptRoot -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % { [Int]::Parse($_.Name) } | Sort-Object | % {
    if ($_ -le $versionNo) {
        $versionFolder = Join-Path $PSScriptRoot "$_"
    }
}
if ($versionFolder -eq "") {
    throw "unable to locate installation folder"
}

Copy-Item -Path "$versionFolder\*" -Destination $PSScriptRoot -Recurse -Force

# Remove version specific folders
Get-ChildItem -Path $PSScriptRoot -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % {
    Remove-Item (Join-Path $PSScriptRoot $_.Name) -Recurse -Force -ErrorAction Ignore
}

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
