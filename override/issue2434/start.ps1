Param( 
    [switch] $installOnly,
    [switch] $filesOnly,
    [switch] $multitenant,
    [string] $artifactUrl = "",
    [switch] $includeTestToolkit,
    [switch] $includeTestLibrariesOnly,
    [switch] $includeTestFrameworkOnly,
    [switch] $includePerformanceToolkit
)

Set-ExecutionPolicy Unrestricted

$runPath = "c:\Run"
$myPath = Join-Path $runPath "my"
$navDvdPath = "C:\NAVDVD"
$navDvdPathCreated = $false
$navFSPath = "C:\NAVFS"
$dlPath = "C:\DL"
$dlPathCreated = $false
$rebootContainer = $false

$publicDnsNameFile = "$RunPath\PublicDnsName.txt"
$restartingInstance = Test-Path -Path $publicDnsNameFile -PathType Leaf

if (!$filesOnly) {
    $filesOnly = ($env:filesOnly -eq "True")
}

$myStart = Join-Path $myPath "start.ps1"
if ($PSCommandPath -ne $mystart) {
    if (Test-Path -Path $myStart) {
        . $myStart -installOnly:$installOnly -filesOnly:$filesOnly -multitenant:$multitenant -artifactUrl $artifactUrl -includeTestToolkit:$includeTestToolkit -includeTestLibrariesOnly:$includeTestLibrariesOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly -includePerformanceToolkit:$includePerformanceToolkit
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

$cimInstance = Get-CIMInstance Win32_OperatingSystem
if ($cimInstance.TotalVisibleMemorySize -lt 3145728) {
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

. (Get-MyFilePath "HelperFunctions.ps1")

if (!$multitenant) {
    $multitenant = ($env:multitenant -eq "Y")
}

try {

    if (!$restartingInstance) {

        if ("$(hostname)" -ne "$env:computername") {
            Write-Host "Adding $env:computername to hosts file"
            New-Item -Path 'c:\windows\system32\drivers\etc\hosts' -ItemType File -ErrorAction Ignore | Out-Null
            Add-Content -Path 'c:\windows\system32\drivers\etc\hosts' -Value "127.0.0.1 $env:computername"
        }

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
    
        if (!(get-service | Where-Object { $_.Name -like 'MicrosoftDynamicsNavServexr*' })) {
    
            if (-not (Test-Path $navDvdPath -PathType Container)) {
                if (!($artifactUrl)) {
                    $artifactUrl = "$env:ArtifactUrl"
                }

                if ($artifactUrl) {

                    Write-Host "Using artifactUrl $($artifactUrl.split('?')[0])"

                    $artifactPaths = Download-Artifacts -artifactUrl $artifactUrl -includePlatform
                    $appArtifactPath = $artifactPaths[0]
                    $platformArtifactPath = $artifactPaths[1]

                    $useNewFolder = $false
                    $mtParam = @{}
                    $versionFolder = $env:installfolder
                    if (!($versionFolder)) {
                        $setupVersion = (Get-Item -Path (Join-Path $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe")).VersionInfo.FileVersion
                        $versionNo = [Int]::Parse($setupVersion.Split('.')[0]+$setupVersion.Split('.')[1])
                        $versionFolder = ""

                        Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % { [Int]::Parse($_.Name) } | Sort-Object | % {
                            if ($_ -le $versionNo) {
                                $versionFolder = Join-Path "C:\Run" $_
                            }
                        }

                        if ($env:doNotUseNewFolder -ne "Y") {
                            if ($versionNo -ge 150) {
                                $useNewFolder = $true
                            }
                            if (($versionFolder) -and (Test-Path "$versionFolder-new")) {
                                $versionFolder = "$versionFolder-new"
                                $useNewFolder = $true
                                $rebootContainer = $true
                            }
                            if ($useNewFolder) {
                                $mtParam = @{ "multitenant" = $multitenant; "rebootContainer" = $rebootContainer }
                            }
                        }
                    }
                    
                    Write-Host "Using installer from $versionFolder"
                    if ($versionFolder -ne "") {
                        if (Test-Path "c:\run\navinstall.ps1") {
                            Write-Host "navinstall was overridden"
                            Remove-Item "$versionFolder\navinstall.ps1"
                        }
                        if (Test-Path "c:\run\servicesettings.ps1") {
                            Write-Host "servicesettings was overridden"
                            Remove-Item "$versionFolder\servicesettings.ps1"
                        }
                        if (Test-Path "c:\run\SetupWebClient.ps1") {
                            Write-Host "SetupWebClient was overridden"
                            Remove-Item "$versionFolder\SetupWebClient.ps1"
                        }
                        Copy-Item -Path "$versionFolder\*" -Destination "C:\Run" -Recurse -Force
                    }
        
                    # Remove version specific folders
                    Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % {
                        Remove-Item (Join-Path "C:\Run" $_.Name) -Recurse -Force -ErrorAction Ignore
                    }

                    if ($useNewFolder) {

                        $appManifestPath = Join-Path $appArtifactPath "manifest.json"
                        $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
    
                        $database = $appManifest.database
                        $databasePath = Join-Path $appArtifactPath $database
    
                        $licenseFile = ""
                        if ($appManifest.PSObject.Properties.name -eq "licenseFile") {
                            $licenseFile = $appManifest.licenseFile
                            if ($licenseFile) {
                                $licenseFilePath = Join-Path $appArtifactPath $licenseFile
                            }
                        }
                        if ("$($env:IsBcSandbox)" -eq "") {
                            if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
                                if ($appManifest.isBcSandbox) {
                                    $env:IsBcSandbox = "Y"
                                }
                            }
                        }
    
                        $useBakFile = ("$env:bakfile" -ne "" -or "$env:appBacpac" -ne "")
                        $useForeignDb = !(("$env:databaseServer" -eq "" -and "$env:databaseInstance" -eq "") -or ("$env:databaseServer" -eq "localhost" -and "$env:databaseInstance" -eq "SQLEXPRESS"))
                        $useOwnLicenseFile = ("$env:licenseFile" -ne "")
    
                        if ($useBakFile -or $useForeignDb) {
                            $databasePath = ""
                            $licenseFile = ""
                        }
                        elseif ($useOwnLicenseFile) {
                            $licenseFile = ""
                        }

                        . (Get-MyFilePath "navinstall.ps1") -appArtifactPath $appArtifactPath -platformArtifactPath $platformArtifactPath -databasePath $databasePath -licenseFilePath $licenseFilePath -installOnly:$installOnly -filesOnly:$filesOnly -includeTestToolkit:$includeTestToolkit -includeTestLibrariesOnly:$includeTestLibrariesOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly @mtParam
                    }
                    else {
                        $tmpFolder = 'c:\$tmp$'
                        if (Test-Path $tmpFolder) {
                            Remove-Item $tmpFolder -Recurse -Force
                            Write-Host "Unexpected restart during artifact copy, retrying..."
                        }
                        New-Item $tmpFolder -ItemType Directory | Out-Null

                        $appManifestPath = Join-Path $appArtifactPath "manifest.json"
                        $appManifest = Get-Content $appManifestPath | ConvertFrom-Json
    
                        $database = $appManifest.database
                        $databasePath = Join-Path $appArtifactPath $database
    
                        $licenseFile = ""
                        if ($appManifest.PSObject.Properties.name -eq "licenseFile") {
                            $licenseFile = $appManifest.licenseFile
                            if ($licenseFile) {
                                $licenseFilePath = Join-Path $appArtifactPath $licenseFile
                            }
                        }
                        if ("$($env:IsBcSandbox)" -eq "") {
                            if ($appManifest.PSObject.Properties.name -eq "isBcSandbox") {
                                if ($appManifest.isBcSandbox) {
                                    $env:IsBcSandbox = "Y"
                                }
                            }
                        }
            
                        Write-Host "Copying Platform Artifacts"
                        RoboCopyFiles -source $platformArtifactPath -Destination $tmpFolder -e 

                        $useBakFile = ("$env:bakfile" -ne "")
                        $useForeignDb = !(("$env:databaseServer" -eq "" -and "$env:databaseInstance" -eq "") -or ("$env:databaseServer" -eq "localhost" -and "$env:databaseInstance" -eq "SQLEXPRESS"))
                        $useOwnLicenseFile = ("$env:licenseFile" -ne "")
    
                        Write-Host "Copying Application Artifacts"
                        if (!($useBakFile -or $useForeignDb)) {
                            $dbPath = Join-Path $tmpFolder "SQLDemoDatabase\CommonAppData\Microsoft\Microsoft Dynamics NAV\ver\Database"
                            New-Item $dbPath -ItemType Directory | Out-Null
                            Write-Host "Copying Database"
                            Copy-Item -path $databasePath -Destination $dbPath -Force
                            if ($licenseFile -and !$useOwnLicenseFile) {
                                Write-Host "Copy Licensefile"
                                Copy-Item -path $licenseFilePath -Destination $dbPath -Force
                            }
                        }
    
                        "Installers", "ConfigurationPackages", "TestToolKit", "UpgradeToolKit", "Extensions", "Applications","Applications.*","My" | % {
                            $appSubFolder = Join-Path $appArtifactPath $_
                            if (Test-Path "$appSubFolder" -PathType Container) {
                                $destFolder = Join-Path $tmpFolder $_
                                if (Test-Path $destFolder) {
                                    Remove-Item -path $destFolder -Recurse -Force
                                }
                                Write-Host "Copying $_"
                                RoboCopyFiles -source $appSubFolder -Destination "$tmpFolder\$_" -e 
                            }
                        }
    
                        while (Test-Path $tmpFolder) {
                            try {
                                Rename-Item -Path $tmpFolder -NewName 'NAVDVD'
                            }
                            catch {
                                Write-Host "WARNING: Unable to rename temp folder, waiting 10 seconds for access..."
                                Start-Sleep -Seconds 10
                            }
                        }
                        $navDvdPathCreated = $true

                        . (Get-MyFilePath "navinstall.ps1") -installOnly:$installOnly
                    }
                }
            }
            elseif (Test-Path $navDvdPath -PathType Container) {
                $setupVersion = (Get-Item -Path "$navDvdPath\ServiceTier\program files\Microsoft Dynamics NAV\*\Service\Microsoft.Dynamics.Nav.Server.exe").VersionInfo.FileVersion
                $versionNo = [Int]::Parse($setupVersion.Split('.')[0]+$setupVersion.Split('.')[1])
                $versionFolder = ""
                Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % { [Int]::Parse($_.Name) } | Sort-Object | % {
                    if ($_ -le $versionNo) {
                        $versionFolder = Join-Path "C:\Run" $_
                    }
                }

                $useNewFolder = $false
                $mtParam = @{}
                if ($env:doNotUseNewFolder -ne "Y") {
                    if (($versionFolder) -and (Test-Path "$versionFolder-new")) {
                        $versionFolder = "$versionFolder-new"
                        $useNewFolder = $true
                        if ($multitenant) {
                            $mtParam = @{ "multitenant" = $true }
                        }
                    }
                }

                Write-Host "Using installer from $versionFolder"
                if ($versionFolder -ne "") {
                    if (Test-Path "c:\run\navinstall.ps1") {
                        Write-Host "navinstall was overridden"
                        Remove-Item "$versionFolder\navinstall.ps1"
                    }
                    if (Test-Path "c:\run\servicesettings.ps1") {
                        Write-Host "servicesettings was overridden"
                        Remove-Item "$versionFolder\servicesettings.ps1"
                    }
                    if (Test-Path "c:\run\SetupWebClient.ps1") {
                        Write-Host "SetupWebClient was overridden"
                        Remove-Item "$versionFolder\SetupWebClient.ps1"
                    }
                    Copy-Item -Path "$versionFolder\*" -Destination "C:\Run" -Recurse -Force
                }

                # Remove version specific folders
                Get-ChildItem -Path "C:\Run" -Directory | where-object { [Int]::TryParse($_.Name, [ref]$null) } | % {
                    Remove-Item (Join-Path "C:\Run" $_.Name) -Recurse -Force -ErrorAction Ignore
                }
                
                if ($useNewFolder) {
                    . (Get-MyFilePath "navinstall.ps1") -installOnly:$installOnly -filesOnly:$filesOnly -includeTestToolkit:$includeTestToolkit -includeTestLibrariesOnly:$includeTestLibrariesOnly -includeTestFrameworkOnly:$includeTestFrameworkOnly -includePerformanceToolkit:$includePerformanceToolkit @mtParam
                }
                else {
                    . (Get-MyFilePath "navinstall.ps1") -installOnly:$installOnly @mtParam
                }
            } else {
                throw "You must share a DVD folder to $navDvdPath or a file system to $navFSPath in order to run the generic image"
            }
        }
    }

    if (!$installOnly) {
        if ($filesOnly) {
            Write-Host "Ready for connections!"
        }
        else {
            . (Get-MyFilePath "navstart.ps1")
        }
    }

} catch {

    Write-Host -ForegroundColor Red $_.Exception.Message

    if ($installOnly) {
        throw "Installation failed"
    }
    elseif ("$env:ExitOnError" -ne "N") {
        return
    }

    Write-Host -ForegroundColor Red $_.ScriptStackTrace

}

if ($dlPathCreated) {
    Write-host "Remove $dlPath"
    Remove-Item $dlPath -Recurse -Force
}
if ($navDvdPathCreated) {
    Write-Host "remove $navDvdPath"
    Remove-Item $navDvdPath -Recurse -Force
}

if (!$installOnly) {
    . (Get-MyFilePath "MainLoop.ps1")
}
