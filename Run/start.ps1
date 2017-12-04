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
        $versionNo = $setupVersion.Split('.')[0]+$setupVersion.Split('.')[1]
        $versionFolder = Join-Path $PSScriptRoot $versionNo
        if (Test-Path $versionFolder) {
            Copy-Item -Path "$versionFolder\*" -Destination $PSScriptRoot -Recurse -Force
        }

        # Remove version specific folders
        "70","71","80","90","100","110" | % {
            Remove-Item (Join-Path $PSScriptRoot $_) -Recurse -Force -ErrorAction Ignore
        }

        . (Get-MyFilePath "navinstall.ps1")

        # run local installers if present
        if (Test-Path "C:\NAVDVD\Installers" -PathType Container) {
            Get-ChildItem "C:\NAVDVD\Installers" -Recurse | Where-Object { $_.PSIsContainer } | % {
                $dir = $_.FullName
                Get-ChildItem (Join-Path $dir "*.msi") | % {
                    $filepath = $_.FullName
                    if ($filepath.Contains('\WebHelp\')) {
                        Write-Host "Skipping $filepath"
                    } else {
                        Write-Host "Installing $filepath"
                        Start-Process -FilePath $filepath -WorkingDirectory $dir -ArgumentList "/qn /norestart" -Wait
                    }
                }
            }
        }
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
