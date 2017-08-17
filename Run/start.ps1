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

    . (Get-MyFilePath "HelperFunctions.ps1")
    . (Get-MyFilePath "navstart.ps1")

} catch {

    Write-Host -ForegroundColor Red $_.Exception.Message
    Write-Host -ForegroundColor Red $_.ScriptStackTrace

    if ("$env:ExitOnError" -ne "N") {
        return
    }
}
. (Get-MyFilePath "MainLoop.ps1")
