function BuildAndPushGeneric
{
    Param(
        [string] $registry = "",
        [string] $maintainer = "Dynamics SMB",
        [string] $eula = "https://go.microsoft.com/fwlink/?linkid=861843",
        [string] $tag = "",
        [string] $windowsservercoreImage = "microsoft/dotnet-framework:4.7.1-windowsservercore-ltsc2016",
        [string] $imageFolder,
        [string] $baseVersionTag = "",
        [bool] $removeImage = $false,
        [bool] $silent = $false,
        [bool] $latest = $true
    )

    if ($registry -ne "" -and $registry[$registry.Length-1] -ne "/") { $registry += "/" }

    if ($silent) {
        $out = Get-Command "Out-Null"
    } else {
        $out = Get-Command "Out-Host"
    }

    docker pull $windowsservercoreImage
    $osversion = docker inspect --format "{{.OsVersion}}" $windowsservercoreImage

    $imageNameTag = "dynamics-nav:generic$baseVersionTag"

    Write-Host -ForegroundColor Yellow "Build $imageNameTag"
    
    $installPath = Join-Path $imageFolder 'Run\Install'
    if (!(Test-Path $installPath))
    {
        New-Item -ItemType Directory -Force $installPath
    }
    
    $t2embedFile = Join-Path $installPath 't2embed.dll'
    if (!(Test-Path $t2embedFile ))
    {
        Copy-Item -Path 'C:\Windows\System32\t2embed.dll' -Destination $t2embedFile
    }
    $hlinkFile = Join-Path $installPath 'hlink.dll'
    if (!(Test-Path $hlinkFile ))
    {
        Copy-Item -Path 'C:\Windows\SysWOW64\hlink.dll' -Destination $hlinkFile
    }
    $mageExeFile = Join-Path $installPath 'mage.exe'
    if (!(Test-Path $mageExeFile ))
    {
        Copy-Item -Path 'C:\temp\mage.exe' -Destination $mageExeFile
    }
    $ReportBuilderFolder = Join-Path $installPath 'ReportBuilder'
    if (!(Test-Path $reportBuilderFolder -PathType Container)) {
        Copy-Item -Path 'C:\temp\ReportBuilder' -Destination $installPath -Recurse
    }
    $ReportBuilder2016Folder = Join-Path $installPath 'ReportBuilder2016'
    if (!(Test-Path $reportBuilder2016Folder -PathType Container)) {
        Copy-Item -Path 'C:\temp\ReportBuilder2016' -Destination $installPath -Recurse
    }
    
    $created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

    $dockerFile = Join-Path $imageFolder 'DOCKERFILE'
    
    "FROM $windowsservercoreImage" | Set-Content $dockerFile
   
@'

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install the prerequisites first to be able reuse the cache when changing only the scripts.
# Temporary workaround for Windows DNS client weirdness (need to check if the issue is still present or not).
# Remove docker files from Sql server image
RUN Add-WindowsFeature Web-Server,web-AppInit,web-Asp-Net45,web-Windows-Auth,web-Dyn-Compression ; \
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name ServerPriorityTimeLimit -Value 0 -Type DWord; \
    Invoke-WebRequest -Uri "https://download.microsoft.com/download/9/0/7/907AD35F-9F9C-43A5-9789-52470555DB90/ENU/SQLEXPR_x64_ENU.exe" -OutFile "sqlexpress.exe" ; \
    Start-Process -Wait -FilePath .\sqlexpress.exe -ArgumentList /qs, /x:setup ; \
    .\setup\setup.exe /q /ACTION=Install /INSTANCENAME=SQLEXPRESS /FEATURES=SQLEngine /UPDATEENABLED=0 /SQLSVCACCOUNT='NT AUTHORITY\System' /SQLSYSADMINACCOUNTS='BUILTIN\ADMINISTRATORS' /TCPENABLED=1 /NPENABLED=0 /IACCEPTSQLSERVERLICENSETERMS ; \
    Remove-Item -Recurse -Force sqlexpress.exe, setup ; \
    Stop-Service 'W3SVC' ; \
    Stop-Service 'MSSQL$SQLEXPRESS' ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpdynamicports -value '' ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\supersocketnetlib\tcp\ipall' -name tcpport -value 1433 ; \
    Set-itemproperty -path 'HKLM:\software\microsoft\microsoft sql server\mssql13.SQLEXPRESS\mssqlserver\' -name LoginMode -value 2 ; \
    Set-Service 'W3SVC' -startuptype "manual" ; \
    Set-Service 'MSSQL$SQLEXPRESS' -startuptype "manual" ; \
    Set-Service 'SQLTELEMETRY$SQLEXPRESS' -startuptype "manual" ; \
    Set-Service 'SQLWriter' -startuptype "manual" ; \
    Set-Service 'SQLBrowser' -startuptype "manual" 
    
COPY Run /Run/

HEALTHCHECK --interval=30s --timeout=10s CMD [ "powershell", ".\\Run\\HealthCheck.ps1" ]

EXPOSE 1433 80 8080 443 7045-7049

CMD .\Run\start.ps1
'@ | Add-Content $dockerFile

    docker rmi $imageNameTag -f 2>NULL | Out-Null
    docker build --label maintainer="$maintainer" `
                 --label created="$created" `
                 --label tag="$tag" `
                 --label osversion="$osversion" `
                 --label eula="$eula" `
                 -t $imageNameTag `
                 $imageFolder | & $out
    if ($LastExitCode -ne 0) {
        throw "Docker build error"
    }
    Write-Host -ForegroundColor Green "Success"
    
    if ($registry -ne "") {
    
        $imageNameTags = @()
        if ($latest) {
            $imageNameTags += "$registry$imageNameTag"
        }
        if ($tag) {
            $imageNameTags += "$registry${imageNameTag}-$tag"
        }
    
        $imageNameTags | % {
            $extraTag = $_
            docker tag $imageNameTag $extraTag | Out-Null
            if ($LastExitCode -ne 0) {
                throw "Docker tag error"
            }
        }
        $imageNameTags | % {
            $extraTag = $_
            Write-Host -ForegroundColor Yellow "Push $extraTag"
            docker push $extraTag | Out-Null
            if ($LastExitCode -ne 0) {
                throw "Docker push error"
            }
            Write-Host -ForegroundColor Green "Success"
        }
        $imageNameTags | % {
            $extraTag = $_
            docker rmi $extraTag -f | Out-Null
            if ($LastExitCode -ne 0) {
                throw "Docker remove error"
            }
        }
    }
    
    if ($removeImage) {
        Write-Host -foregroundColor Yellow "Remove $ImageNameTag"
        docker rmi $imageNameTag -f | Out-Null
        if ($LastExitCode -ne 0) {
            throw "Docker remove error"
        }
        Write-Host -ForegroundColor Green "Success"
    }
}
