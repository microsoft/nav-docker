Set-ExecutionPolicy Unrestricted

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

$Source = @"
	using System.Net;
 
	public class MyWebClient : WebClient
	{
		protected override WebRequest GetWebRequest(System.Uri address)
		{
			WebRequest request = base.GetWebRequest(address);
			if (request != null)
			{
				request.Timeout = -1;
			}
			return request;
		}
 	}
"@;
 
Add-Type -TypeDefinition $Source -Language CSharp -WarningAction SilentlyContinue | Out-Null


try {

    if (!$restartingInstance) {
        $folders = "$env:folders"

        if ($folders -ne "") {
            Write-Host "Setting up folders..."
            $startTime = [DateTime]::Now
            $foldersArray = $folders -split ","
            foreach ($folder in $foldersArray) {
                $folderValue = $folder -split "="
                $dir = $folderValue[0]
                $value = $folderValue[1].Split('\')[0]
                $subfolder = $folderValue[1].Split('\')[1]
                Write-Host "Downloading $value to $dir"
                if (-not (Test-Path $dir)) {
                    New-Item $dir -ItemType Directory | Out-Null
                }
                $temp = [System.Guid]::NewGuid();new-item -type directory -Path c:\run\$temp | Out-Null
                (New-Object MyWebClient).DownloadFile($value, "c:\run\$temp\download.zip")

                Write-Host "Extracting file in temp folder"
                Expand-Archive "c:\run\$temp\download.zip" -DestinationPath "c:\run\$temp\extract" -Force

                if ($subfolder) {
                    Write-Host "Moving $subfolder to target folder $dir"
                    Get-ChildItem -Path "c:\run\$temp\extract\$subfolder\*" -Recurse | Move-Item -Destination $dir -Force
                } else {
                    Write-Host "Moving all extracted files to target folder $dir"
                    Get-ChildItem -Path "c:\run\$temp\extract\*" -Recurse | Move-Item -Destination $dir -Force
                }
                Remove-Item "c:\run\$temp" -Recurse -Force
            }
            $timespend = [Math]::Round([DateTime]::Now.Subtract($startTime).Totalseconds)
            Write-Host "Setting up folders took $timespend seconds"
        }
    
        if (!(Test-Path "C:\Program Files\Microsoft Dynamics NAV" -PathType Container)) {
    
            if (!(Test-Path $navDvdPath -PathType Container)) {
                throw "You must share a DVD folder to $navDvdPath to run the generic image"
            }
            
            $setupVersion = (Get-Item -Path "$navDvdPath\setup.exe").VersionInfo.FileVersion
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
    }

    . (Get-MyFilePath "navstart.ps1")

} catch {

    Write-Host -ForegroundColor Red $_.Exception.Message

    if ("$env:ExitOnError" -ne "N") {
        return
    }

    Write-Host -ForegroundColor Red $_.ScriptStackTrace

}
. (Get-MyFilePath "MainLoop.ps1")
