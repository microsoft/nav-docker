Set-ExecutionPolicy Unrestricted

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

try {

    if (!(Test-Path "C:\Program Files\Microsoft Dynamics NAV" -PathType Container)) {
        if (!(Test-Path "C:\NAVDVD" -PathType Container)) {
            throw "You must share a DVD folder to C:\NAVDVD to run the generic image"
        }
        
        $setupVersion = (Get-Item -Path "c:\navdvd\setup.exe").VersionInfo.FileVersion
        $versionFolder = $setupVersion.Split('.')[0]+$setupVersion.Split('.')[1]
        Copy-Item -Path (Join-Path $PSScriptRoot "$versionFolder\*.*") -Destination $PSScriptRoot -Force
        
        . (Join-Path $PSScriptRoot "navinstall.ps1")
    }

    . (Get-MyFilePath "HelperFunctions.ps1")
    . (Get-MyFilePath "navstart.ps1")

} catch {

    Write-Host -ForegroundColor Red $_.Exception.Message

    if ("$env:ExitOnError" -ne "N") {
        return
    }

    Write-Host -ForegroundColor Red $_.ScriptStackTrace

}
. (Get-MyFilePath "MainLoop.ps1")
