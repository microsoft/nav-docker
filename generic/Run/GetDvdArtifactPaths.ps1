<#
.SYNOPSIS
Gets the path to the server's W1DVD Service folder
.DESCRIPTION
Gets the path to the server's W1DVD Service folder
#>
function Get-NavDvdServiceFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $ServiceFolder = Join-Path $platformArtifactPath "ServiceTier\pfiles64\Microsoft Dynamics NAV\*\Service"
    if (!(Test-Path $ServiceFolder)) {
        # Use the legacy folder path used before version 27 (wix 6.0)
        $ServiceFolder = Join-Path $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service"
    }

    return (Get-Item $ServiceFolder).FullName
}

<#
.SYNOPSIS
Gets the name of the Common App Data folder on the dvd image
.DESCRIPTION
Gets the name of the Common App Data folder on the dvd image
#>
function Get-WixCommonAppData {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $CommonAppData = "CommApp"
    $databaseFolder = Join-Path $platformArtifactPath "SQLDemoDatabase\$CommonAppData"
    if (!(Test-Path $databaseFolder -PathType Container)) {
        # Use the legacy folder path used before version 27 (wix 6.0)
        $CommonAppData = "CommonAppData"
    }

    return $CommonAppData
}

<#
.SYNOPSIS
Gets the name of the Program Files folder on the dvd image
.DESCRIPTION
Gets the name of the Program Files folder on the dvd image
#>
function Get-WixProgramFiles64 {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $pfiles64 = "pfiles64"
    $ServiceFolder = Join-Path $platformArtifactPath "ServiceTier\$pfiles64\Microsoft Dynamics NAV\*\Service"
    if (!(Test-Path $ServiceFolder)) {
        # Use the legacy folder path used before version 27 (wix 6.0)
        $pfiles64 = "program files"
    }

    return $pfiles64
}

<#
.SYNOPSIS
Gets the path to the DevTools W1DVD folder
.DESCRIPTION
Gets the path to the DevTools W1DVD folder
#>
function Get-NavDvdDevToolsFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $rootPath = Join-Path $platformArtifactPath "ModernDev\pfiles"
    if (!(Test-Path $rootPath)) {
        # Use the legacy folder path used before version 27 and wix 6.0
        $rootPath = Join-Path $platformArtifactPath "ModernDev\program files"
    }

    return (Join-Path $rootPath "Microsoft Dynamics NAV")
}

<#
.SYNOPSIS
Gets the path to the WebRoot W1DVD folder
.DESCRIPTION
Gets the path to the WebRoot W1DVD folder
#>
function Get-NavDvdWebRootFolder {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $WebRoot = Join-Path $platformArtifactPath "WebClient\pfiles\Microsoft Dynamics NAV"
    if (!(Test-Path $webRoot))
    {
        # Use the legacy folder path used before version 27 and wix 6.0
        $WebRoot = Join-Path $platformArtifactPath "WebClient\Microsoft Dynamics NAV"        
    }

    return $WebRoot
}

<#
.SYNOPSIS
Gets the path to the NavSip component on the W1DVD
.DESCRIPTION
Gets the path to the NavSip component on the W1DVD
#>
function Get-NavDvdSipComponentPath {
    Param(
        [Parameter(Mandatory=$true)]
        [string] $platformArtifactPath
    )

    $sipComponent = Join-Path $platformArtifactPath "ServiceTier\System64\NavSip.dll"
    if (!(Test-Path $sipComponent)) {
        # Use the legacy folder path used before version 27 and wix 6.0
        $sipComponent = Join-Path $platformArtifactPath "ServiceTier\System64Folder\NavSip.dll"
    }

    return $sipComponent
}
