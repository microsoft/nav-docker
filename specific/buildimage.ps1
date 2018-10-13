Param(
    [string] $NAVDVDURL = "",
    [string] $VSIXURL = ""
)

Write-Host "NAVDVDURL '$NAVDVDURL'"
Write-Host "VSIXURL '$VSIXURL'"

#if ("$NAVDVDURL" -ne "") {
#    Write-Host "Downloading NAVDVD $NAVDVDURL"
#    (New-Object System.Net.WebClient).DownloadFile("$NAVDVDURL", "C:\NAVDVD.zip")
#    [Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.Filesystem") | Out-Null
#    [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\NAVDVD.zip","C:\NAVDVD\")
#    Remove-Item -Path "C:\NAVDVD.zip" -Force
#}
#if ("$VSIXURL" -ne "") {
#    Write-Host "Downloading VSIX"
#    (New-Object System.Net.WebClient).DownloadFile("$VSIXURL", ("C:\NAVDVD\"+"$VSIXURL".Substring("$VSIXURL".LastIndexOf("/")+1)))
#}
#
#$setupVersion = (Get-Item -Path "c:\navdvd\setup.exe").VersionInfo.FileVersion
#$versionNo = [Int]::Parse($setupVersion.Split('.')[0]+$setupVersion.Split('.')[1])
#$versionFolder = ""
#Get-ChildItem -Path $PSScriptRoot -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % { [Int]::Parse($_.Name) } | Sort-Object | % {
#    if ($_ -le $versionNo) {
#        $versionFolder = Join-Path $PSScriptRoot "$_"
#    }
#}
#if ($versionFolder -eq "") {
#    throw "unable to locate installation folder"
#}
#
#Copy-Item -Path "$versionFolder\*" -Destination $PSScriptRoot -Recurse -Force
#
## Remove version specific folders
#Get-ChildItem -Path $PSScriptRoot -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % {
#    Remove-Item (Join-Path $PSScriptRoot $_.Name) -Recurse -Force -ErrorAction Ignore
#}
#
#. (Join-Path $PSScriptRoot "navinstall.ps1")
#
#if ("$NAVDVDURL" -ne "") {
#    while (Test-Path -Path "C:\NAVDVD" -PathType Container) {
#        try {
#            Remove-Item -Path "C:\NAVDVD" -Force -Recurse
#        } catch {
#            Start-sleep -Seconds 5
#        }
#    }
#}
#
#Remove-Item "c:\run\navinstall.ps1" -Force
#Remove-Item "c:\run\buildimage.ps1" -Force
#