Param( 
    [switch] $installOnly,
    [string] $artifactUrl = ""
)

Set-ExecutionPolicy Unrestricted

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"
$navDvdPathCreated = $false
$navFSPath = "C:\NAVFS"
$dlPath = "C:\DL"
$dlPathCreated = $false

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf

$myStart = Join-Path $myPath "start.ps1"
if ($PSCommandPath -ne $mystart) {
    if (Test-Path -Path $myStart) {
        . $myStart
        exit
    }
}

function Get-MyFilePath([string]$FileName)
{
    if ((Test-Path $myPath -PathType Container) -and (Test-Path (Join-Path $myPath $FileName) -PathType Leaf)) {
        (Join-Path $myPath $FileName)
    } else {
        (Join-Path $runPath $FileName)
    }
}

if ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory -lt 3221225472) {
    throw "At least 3Gb memory needs to be available to the Container."
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
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

try {

    if (!$restartingInstance) {
        $folders = "$env:folders"

        if ($folders -ne "") {
            Write-Host "Setting up folders..."
            $startTime = [DateTime]::Now
            $foldersArray = $folders -split ","
            foreach ($folder in $foldersArray) {
                $idx = $folder.indexof('=')
                $dir = $folder.Substring(0,$idx)
                $value = $folder.Substring($idx+1).Split('\')[0]
                $subfolder = $folder.Substring($idx+1).Split('\')[1]
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

        if (Test-Path $navFsPath -PathType Container) {
            Write-Host "Copying files from $NavFsPath"
            Get-ChildItem -Path $navFSPath | ForEach-Object {
                Copy-Item -Path "$navFSPath\$($_.Name)" -Destination "c:\" -recurse -force
            }
        }
    
        if (!(Test-Path "C:\Program Files\Microsoft Dynamics NAV\*\Service\*.exe" -PathType Leaf)) {
    
            if (-not (Test-Path $navDvdPath -PathType Container)) {
                if (!($artifactUrl)) {
                    $artifactUrl = $env:ArtifactUrl
                }

                if ($artifactUrl) {
                    if (-not (Test-Path $dlPath)) {
                        New-Item $dlPath -ItemType Directory | Out-Null
                        $dlPathCreated = $true
                    }
    
                    do {
                        $redir = $false
                        $appUri = [Uri]::new($artifactUrl)
    
                        $appArtifactPath = Join-Path $dlPath $appUri.AbsolutePath
                        if (-not (Test-Path $appArtifactPath)) {
                            Write-Host "Downloading application artifact $($appUri.AbsolutePath)"
                            (New-Object MyWebClient).DownloadFile($artifactUrl, "c:\run\app.zip")
                            Write-Host "Unpacking application artifact"
                            Expand-Archive -Path "c:\run\app.zip" -DestinationPath $appArtifactPath -Force
                        }
    
                        $appManifestPath = Join-Path $appArtifactPath "manifest.json"
                        $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
    
                        if ($appManifest.PSObject.Properties.name -eq "applicationUrl") {
                            $redir = $true
                            $artifactUrl = $appManifest.ApplicationUrl
                        }
    
                    } while ($redir)
    
                    $database = $appManifest.database
                    $databasePath = Join-Path $appArtifactPath $database
                    $licenseFile = $appManifest.licenseFile
                    $licenseFilePath = Join-Path $appArtifactPath $licenseFile
    
                    $platformUrl = $appManifest.platformUrl
                    $platformUri = [Uri]::new($platformUrl)
                     
                    $platformArtifactPath = Join-Path $dlPath $platformUri.AbsolutePath
    
                    if (-not (Test-Path $platformArtifactPath)) {
                        Write-Host "Downloading platform artifact $($platformUri.AbsolutePath) - $platformUrl"
                        (New-Object MyWebClient).DownloadFile($platformUrl, "c:\run\platform.zip")
                        Write-Host "Unpacking platform artifact"
                        Expand-Archive -Path "c:\run\platform.zip" -DestinationPath $platformArtifactPath -Force
    
                        $prerequisiteComponentsFile = Join-Path $platformArtifactPath "Prerequisite Components.json"
                        if (Test-Path $prerequisiteComponentsFile) {
                            $prerequisiteComponents = Get-Content $prerequisiteComponentsFile | ConvertFrom-Json
                            Write-Host "Downloading Prerequisite Components"
                            $prerequisiteComponents.PSObject.Properties | % {
                                $path = Join-Path $platformArtifactPath $_.Name
                                if (-not (Test-Path $path)) {
                                    $dirName = [System.IO.Path]::GetDirectoryName($path)
                                    $filename = [System.IO.Path]::GetFileName($path)
                                    if (-not (Test-Path $dirName)) {
                                        New-Item -Path $dirName -ItemType Directory | Out-Null
                                    }
                                    $url = $_.Value
                                    Write-Host "Downloading $filename from $url"
                                    (New-Object MyWebClient).DownloadFile($url, $path)
                                }
                            }
                        }
                    }
    
                    New-Item $navDvdPath -ItemType Directory | Out-Null
                    $navDvdPathCreated = $true
                    Copy-Item -Path "$platformArtifactPath\*" -Destination $navDvdPath -Force -Recurse
                    
                    $useBakFile = ("$env:bakfile" -ne "")
                    $useForeignDb = (!("$env:databaseServer" -eq "" -and "$env:databaseInstance" -eq "") -or ("$env:databaseServer" -eq "localhost" -and "$env:databaseInstance" -eq "SQLEXPRESS"))
                    $useOwnLicenseFile = ("$env:licenseFile" -ne "")

                    if (!($useBakFile -or $useForeignDb)) {
                        $dbPath = Join-Path $navDvdPath "SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\ver\Database"
                        New-Item $dbPath -ItemType Directory | Out-Null
                        Copy-Item -path $databasePath -Destination $dbPath -Force
                        if (!$useOwnLicenseFile) {
                            Copy-Item -path $licenseFilePath -Destination $dbPath -Force
                        }
                    }
    
                    "Installers", "ConfigurationPackages", "TestToolKit", "UpgradeToolKit", "Extensions", "Applications" | % {
                        $appSubFolder = Join-Path $appArtifactPath $_
                        if (Test-Path "$appSubFolder" -PathType Container) {
                            $destFolder = Join-Path $navDvdPath $_
                            if (Test-Path $destFolder) {
                                Write-Host "Remove w1 version of $_"
                                Remove-Item -path $destFolder -Recurse -Force
                            }
                            Write-Host "Copy $_"
                            Copy-Item -Path "$appSubFolder" -Destination $navDvdPath -Recurse
                        }
                    }
                }
            }

            if (Test-Path $navDvdPath -PathType Container) {
                $setupVersion = (Get-Item -Path "$navDvdPath\ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo.FileVersion
                $versionNo = [Int]::Parse($setupVersion.Split('.')[0]+$setupVersion.Split('.')[1])
                $versionFolder = ""
                Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % { [Int]::Parse($_.Name) } | Sort-Object | % {
                    if ($_ -le $versionNo) {
                        $versionFolder = Join-Path "C:\Run" $_
                    }
                }
                if ($versionFolder -ne "") {
                    Copy-Item -Path "$versionFolder\*" -Destination "C:\Run" -Recurse -Force
                }
    
                # Remove version specific folders
                Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % {
                    Remove-Item (Join-Path "C:\Run" $_.Name) -Recurse -Force -ErrorAction Ignore
                }
        
                . (Get-MyFilePath "navinstall.ps1")
            } else {
                throw "You must share a DVD folder to $navDvdPath or a file system to $navFSPath in order to run the generic image"
            }
        }
    }

    if (!$installOnly) {
        . (Get-MyFilePath "navstart.ps1")
    }

} catch {

    Write-Host -ForegroundColor Red $_.Exception.Message

    if ("$env:ExitOnError" -ne "N") {
        return
    }

    Write-Host -ForegroundColor Red $_.ScriptStackTrace

}

if ($dlPathCreated) {
    Remove-Item $dlPath -Recurse -Force
}
if ($navDvdPathCreated) {
    Remove-Item $navDvdPath -Recurse -Force
}

if (!$installOnly) {
    . (Get-MyFilePath "MainLoop.ps1")
}
