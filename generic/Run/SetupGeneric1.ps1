
$sql2019url = 'https://go.microsoft.com/fwlink/p/?linkid=866658'

# https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/build-versions
$sql2019LatestCuUrl = 'https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5035123-x64.exe'

# https://dotnet.microsoft.com/en-us/download/dotnet/6.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet6url = 'https://download.visualstudio.microsoft.com/download/pr/41643a5c-1ed5-41c8-abd0-473112282a79/644e14ace834d476fe3fa6797e472c55/dotnet-hosting-6.0.30-win.exe'

# https://dotnet.microsoft.com/en-us/download/dotnet/8.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet8url = 'https://download.visualstudio.microsoft.com/download/pr/70f96ebd-54ce-4bb2-a90f-2fbfc8fd90c0/aa542f2f158cc6c9e63b4287e4618f0a/dotnet-hosting-8.0.5-win.exe'

# https://github.com/PowerShell/PowerShell/releases - grab the latest PowerShell-7.4.x-win-x64.msi link
$powerShell7url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/PowerShell-7.4.2-win-x64.msi'

# Misc URLs
$rewriteUrl = 'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi'
$sqlncliUrl = 'https://download.microsoft.com/download/B/E/D/BED73AAC-3C8A-43F5-AF4F-EB4FEA6C8F3A/ENU/x64/sqlncli.msi'
$vcredist_x86url = 'https://aka.ms/highdpimfc2013x86enu'
$vcredist_x64url = 'https://aka.ms/highdpimfc2013x64enu'
$vsredist_x64_140url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'

# NAV/BC Docker Install Files
$navDockerInstallUrl = 'https://bcartifacts.blob.core.windows.net/prerequisites/nav-docker-install.zip'
$openXmlSdkV25url = 'https://bcartifacts.blob.core.windows.net/prerequisites/OpenXMLSDKv25.msi'

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
Invoke-RestMethod -Method Get -UseBasicParsing -Uri $vsredist_x64_140url -OutFile 'temp\vcredist_x64_140.exe'
Write-Host 'Installing vcredist_x64_140'
$process = start-process -Wait -FilePath 'temp\vcredist_x64_140.exe' -ArgumentList /q, /norestart
if (($null -ne $process.ExitCode) -and ($process.ExitCode -ne 0)) { Write-Host ('EXIT CODE '+$process.ExitCode) } else { Write-Host 'Success' }
Write-Host 'Removing temp folder'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'temp'
Write-Host 'Cleanup temporary files'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $env:TEMP\*
Write-Host 'Remove x86 dotnet files'
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'C:\Program Files (x86)\dotnet'
