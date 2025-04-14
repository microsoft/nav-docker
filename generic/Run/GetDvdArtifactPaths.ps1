<#
.SYNOPSIS
Gets the path to the server's W1DVD Service folder
.DESCRIPTION
Gets the path to the server's W1DVD Service folder
#>
function Get-NavDvdServiceFolder([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $ServiceFolder = Join-Path -Resolve $platformArtifactPath "ServiceTier\pfiles64\Microsoft Dynamics NAV\*\Service" -ErrorAction Ignore
    if (($null -eq $ServiceFolder) -or !(Test-Path $ServiceFolder))
    {
        # Use the legacy folder path used before version 27 (wix 6.0)
        $ServiceFolder = Join-Path -Resolve  $platformArtifactPath "ServiceTier\program files\Microsoft Dynamics NAV\*\Service" -ErrorAction Ignore
    }

    return $ServiceFolder
}

<#
.SYNOPSIS
Gets the name of the Common App Data folder on the dvd image
.DESCRIPTION
Gets the name of the Common App Data folder on the dvd image
#>
function Get-WixCommonAppData([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $ServiceFolder = Join-Path -Resolve $platformArtifactPath "ServiceTier\pfiles64\Microsoft Dynamics NAV\*\Service" -ErrorAction Ignore
    $CommonAppData = "CommApp"
    if (($null -eq $ServiceFolder) -or !(Test-Path $ServiceFolder))
    {
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
function Get-WixProgramFiles64([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $ServiceFolder = Join-Path -Resolve $platformArtifactPath "ServiceTier\pfiles64\Microsoft Dynamics NAV\*\Service" -ErrorAction Ignore
    $pfiles64 = "pfiles64"
    if (($null -eq $ServiceFolder) -or !(Test-Path $ServiceFolder))
    {
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
function Get-NavDvdDevToolsFolder([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $rootPath = Join-Path $platformArtifactPath "ModernDev\pfiles" -ErrorAction Ignore
    if (($null -eq $rootPath) -or !(Test-Path $rootPath))
    {
        # Use the legacy folder path used before version 27 and wix 6.0
        $rootPath = Join-Path $platformArtifactPath "ModernDev\program files" -ErrorAction Ignore
    }

    $platformPath = Join-Path -Resolve $rootPath "Microsoft Dynamics NAV" -ErrorAction Ignore

    Return "$platformPath"
}

<#
.SYNOPSIS
Gets the path to the WebClient W1DVD folder
.DESCRIPTION
Gets the path to the WebClient W1DVD folder
#>
function Get-NavDvdWebClientFolder([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $WebRoot = Join-Path $platformArtifactPath "WebClient\pfiles\Microsoft Dynamics NAV"
    $webClientFolder = Join-Path -Resolve $WebRoot "*\Web Client" -ErrorAction Ignore
    if (($null -eq $webClientFolder) -or !(Test-Path $webClientFolder))
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
function Get-NavDvdSipComponentPath([string]$platformArtifactPath)
{
    if ($platformArtifactPath -eq $null -or $platformArtifactPath.Count -eq 0)
    {
        Throw "The path to the platform artifact is not specified."
    }

    $sipComponent = Join-Path $platformArtifactPath "ServiceTier\System64\NavSip.dll" -ErrorAction Ignore
    if (($null -eq $sipComponent) -or !(Test-Path $sipComponent))
    {
        # Use the legacy folder path used before version 27 and wix 6.0
        $sipComponent = Join-Path $platformArtifactPath "ServiceTier\System64Folder\NavSip.dll"
    }

    return $sipComponent
}
