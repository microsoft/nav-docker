﻿# INPUT
#     $serviceTierFolder
#     $licenseFile (optional)
#
# OUTPUT
#

if ($restartingInstance) {

    # Nothing to do

} elseif ($licensefile -ne "") {

    if ($multitenant)
    {
        $status = (Get-NavTenant -ServerInstance $ServerInstance).State

        while ($status -eq "Mounting")
        {
            Write-Host "Tenant default was not ready: $($status)"
            Start-Sleep -Seconds 5

            $status = (Get-NavTenant -ServerInstance $ServerInstance).State
        }
    }

    if ($licensefile.StartsWith("https://") -or $licensefile.StartsWith("http://"))
    {
        $licensefileurl = $licensefile
        $licensefile = (Join-Path $runPath "license.flf")
        Write-Host "Downloading license file '$licensefileurl'"
        (New-Object System.Net.WebClient).DownloadFile($licensefileurl, $licensefile)
    } else {
        Write-Host "Using license file '$licensefile'"
        if (!(Test-Path -Path $licensefile -PathType Leaf)) {
        	Write-Error "ERROR: License File not found."
            Write-Error "The file must be uploaded to the container or available on a share."
            exit 1
        }
    }
    Write-Host "Import License"
    Import-NAVServerLicense -LicenseData ([Byte[]]$(Get-Content -Path $licensefile -Encoding Byte)) -ServerInstance $ServerInstance -Database NavDatabase -WarningAction SilentlyContinue
}
