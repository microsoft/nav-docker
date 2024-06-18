. (Join-Path $PSScriptRoot 'SetupUrls.ps1')

Write-Host "FilesOnly=$env:filesOnly"
Write-Host "only24=$env:only24"
$filesonly = $env:filesonly -eq 'true'
$only24 = $env:only24 -eq 'true'
if ($only24) {
    Remove-Item -Recurse -Force Run/70,Run/71,Run/80,Run/90,Run/100,Run/110,Run/130,Run/150,Run/150-new,Run/210,Run/210-new
}
$psarchiveModule = 'C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Microsoft.PowerShell.Archive\Microsoft.PowerShell.Archive.psm1'
if (Test-Path $psarchiveModule) {
    Write-Host 'Updating PowerShell Archive module'
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule((whoami),'Modify','Allow')
    $acl = Get-Acl -Path $psarchiveModule; $acl.AddAccessRule($rule); Set-Acl -Path $psarchiveModule -AclObject $acl
    Set-Content -path $psarchiveModule -value ((Get-Content -path $psarchiveModule) -replace "Import-LocalizedData  LocalizedData -filename ArchiveResources", "Import-LocalizedData LocalizedData -filename ArchiveResources -UICulture 'en-US'")
    Write-Host 'Success'
}
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
[Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.Filesystem') | Out-Null
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name ServerPriorityTimeLimit -Value 0 -Type DWord
Set-ItemProperty -Path 'HKLM:\system\CurrentControlSet\control' -name ServicesPipeTimeout -Value 300000 -Type DWORD -Force
Set-ItemProperty -Path 'HKLM:SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type DWORD -Force
New-Item 'temp' -ItemType Directory | Out-Null
if (-not $filesonly) {
    if ($only24) {
        Write-Host 'Adding Windows Features for BC 24+'
        Add-WindowsFeature Web-Server,web-AppInit,web-Windows-Auth,web-Dyn-Compression,web-WebSockets
        Stop-Service 'W3SVC'
        Set-Service 'W3SVC' -startuptype manual
    }
    else {
        Write-Host 'Adding Windows Features for BC'
        Add-WindowsFeature Web-Server,web-AppInit,web-Asp-Net45,web-Windows-Auth,web-Dyn-Compression,web-WebSockets
        Stop-Service 'W3SVC'
        Set-Service 'W3SVC' -startuptype manual
    }
    Write-Host 'Downloading SQL Server 2019 Express'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $sql2019url -OutFile 'temp\SQL2019-SSEI-Expr.exe'
    $configFileLocation = 'c:\run\SQLConf.ini'
    Write-Host 'Installing SQL Server 2019 Express'
    $process = Start-Process -FilePath 'temp\SQL2019-SSEI-Expr.exe' -ArgumentList /Action=Install, /ConfigurationFile=$configFileLocation, /IAcceptSQLServerLicenseTerms, /Quiet -NoNewWindow -Wait -PassThru
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
    Write-Host 'Downloading SQL Server 2019 Cumulative Update'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $sql2019LatestCuUrl -OutFile 'temp\SQL2019CU.exe'
    Write-Host 'Installing SQL Server 2019 Cumulative Update'
    $process = Start-Process -FilePath 'temp\SQL2019CU.exe' -ArgumentList /Action=Patch, /Quiet, /IAcceptSQLServerLicenseTerms, /AllInstances, /SuppressPrivacyStatementNotice -NoNewWindow -Wait -PassThru
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
    Write-Host 'Configuring SQL Server 2019 Express'
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql15.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value ''
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql15.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql15.SQLEXPRESS\mssqlserver\' -name LoginMode -value 2
    Set-Service 'MSSQL$SQLEXPRESS' -startuptype manual
    Set-Service 'SQLTELEMETRY$SQLEXPRESS' -startuptype manual
    Set-Service 'SQLWriter' -startuptype manual
    Set-Service 'SQLBrowser' -startuptype manual
    Write-Host 'Removing SQL Server 2019 Express Install Files'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'SQL2019'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files\Microsoft SQL Server\150\SSEI'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\Template Data'
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files\Microsoft SQL Server\MSSQL15.SQLEXPRESS\MSSQL\Log\*'
}
Write-Host 'Downloading NAV/BC Docker Install Files'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $navDockerInstallUrl -OutFile 'temp\nav-docker-install.zip'
Write-Host 'Extracting NAV/BC Docker Install Files'
[System.IO.Compression.ZipFile]::ExtractToDirectory('temp\nav-docker-install.zip', 'c:\run')
Write-Host 'Updating PowerShell Execution Policy to Unrestricted'
. C:\Run\UpdatePowerShellExeConfig.ps1
. C:\Run\helperfunctions.ps1
if (-not $filesonly) {
    Write-Host 'Starting SQL Server Services'
    Start-Service -Name $SqlBrowserServiceName -ErrorAction Ignore -WarningAction Ignore
    Start-Service -Name $SqlWriterServiceName -ErrorAction Ignore -WarningAction Ignore
    Start-Service -Name $SqlServiceName -ErrorAction Ignore -WarningAction Ignore
    Write-Host 'Downloading rewrite_amd64'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $rewriteUrl -OutFile 'temp\rewrite_amd64.msi'
    Write-Host 'Installing rewrite_amd64'
    $process = start-process -Wait -FilePath 'temp\rewrite_amd64.msi' -ArgumentList /quiet, /qn, /passive
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
    Write-Host 'Downloading SQL Server Native Client'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $sqlncliUrl -OutFile 'temp\sqlncli.msi'
    Write-Host 'Installing SQL Server Native Client'
    $process = start-process -Wait -FilePath 'temp\sqlncli.msi' -ArgumentList /quiet, /qn, /passive
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
}
Write-Host 'Downloading OpenXMLSDKV25'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $openXmlSdkV25url -OutFile 'temp\OpenXMLSDKV25.msi'
Write-Host 'Installing OpenXMLSDKV25'
$process = start-process -Wait -FilePath 'temp\OpenXMLSDKV25.msi' -ArgumentList /quiet, /qn, /passive
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
Write-Host 'Downloading dotnet 6'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $dotNet6url -OutFile 'temp\DotNet6-Win.exe'
Write-Host 'Installing dotnet 6'
$process = start-process -Wait -FilePath 'temp\DotNet6-Win.exe' -ArgumentList /quiet
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
Write-Host 'Downloading dotnet 8'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $dotNet8url -OutFile 'temp\DotNet8-Win.exe'
Write-Host 'Installing dotnet 8'
$process = start-process -Wait -FilePath 'temp\DotNet8-Win.exe' -ArgumentList /quiet
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
Write-Host 'Downloading PowerShell 7'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $powerShell7url -OutFile 'temp\powershell-7-win-x64.msi'
Write-Host 'Installing PowerShell 7'
$process = start-process -Wait -FilePath 'temp\powershell-7-win-x64.msi' -ArgumentList /quiet
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
if (-not $only24) {
    Write-Host 'Downloading vcredist_x86'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $vcredist_x86url -OutFile 'temp\vcredist_x86.exe'
    Write-Host 'Installing vcredist_x86'
    $process = start-process -Wait -FilePath 'temp\vcredist_x86.exe' -ArgumentList /q, /norestart
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
    Write-Host 'Downloading vcredist_x64'
    Invoke-RestMethod -Method Get -UseBasicParsing -Uri $vcredist_x64url -OutFile 'temp\vcredist_x64.exe'
    Write-Host 'Installing vcredist_x64'
    $process = start-process -Wait -FilePath 'temp\vcredist_x64.exe' -ArgumentList /q, /norestart
    if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
}
Write-Host 'Downloading vcredist_x64_140'
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $vcredist_x64_140url -OutFile 'temp\vcredist_x64_140.exe'
Write-Host 'Installing vcredist_x64_140'
$process = start-process -Wait -FilePath 'temp\vcredist_x64_140.exe' -ArgumentList /q, /norestart
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
Write-Host 'Removing temp folder'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'temp'
Write-Host 'Cleanup temporary files'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $env:TEMP\*
Write-Host 'Remove x86 dotnet files'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files (x86)\dotnet'
