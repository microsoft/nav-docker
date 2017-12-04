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

    $folders = "$env:folders"
    if ($folders -ne "") {
        $foldersArray = $folders -split ","
        foreach ($folder in $foldersArray) {
            $folderValue = $folder -split "="
            $dir = $folderValue[0]
            $value = $folderValue[1].Split('\')[0]
            $subfolder = $folderValue[1].Split('\')[1]
            Write-Host "Downloading and extracting $value to $dir"
            if (-not (Test-Path $dir)) {
                New-Item $dir -ItemType Directory | Out-Null
            }
            (New-Object System.Net.WebClient).DownloadFile($value, "download.zip")
            Expand-Archive "download.zip" -DestinationPath $dir -Force
            if ($subfolder) {
                Get-ChildItem -Path "$dir\$subfolder\*" -Recurse | Move-Item -Destination $dir
                remove-item -Path "$dir\$subfolder" -Force -Recurse -ErrorAction Ignore
            }
            Remove-Item "download.zip" -Force
        }
    }

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
