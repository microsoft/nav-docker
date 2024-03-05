param
(
    [switch]$silent
)

function ImportModule([string] $path) {
    if (Test-Path $path) {
        Import-Module $path -wa SilentlyContinue
    }
}

$isPsCore = [System.Version]$PSVersionTable.PSVersion -ge [System.Version]"7.4.1"

. "c:\run\ServiceSettings.ps1"
if ($PSScriptRoot -eq "c:\run" -and (Test-Path "c:\run\my\prompt.ps1")) {
    . "c:\run\my\prompt.ps1"
}
else {
    $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
    if ($isPsCore -and (Test-Path "$serviceTierFolder\Admin")) {
        ImportModule "$serviceTierFolder\Admin\Microsoft.Dynamics.Nav.Management.psm1"
        ImportModule "$serviceTierFolder\Admin\Microsoft.BusinessCentral.Management.psd1"
        ImportModule "$serviceTierFolder\Admin\Microsoft.BusinessCentral.Apps.Management.dll"
    }
    else {
        if (Test-Path "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1") {
            Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1" -wa SilentlyContinue
        }
        else {
            Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.dll" -wa SilentlyContinue
        }
        $serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
        $roleTailoredClientItem = Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client" -ErrorAction Ignore
        if ($roleTailoredClientItem) {
            $roleTailoredClientFolder = $roleTailoredClientItem.FullName
            $NavIde = Join-Path $roleTailoredClientFolder "finsql.exe"
            if (!(Test-Path $NavIde)) {
                $NavIde = ""
            }
            if (Test-Path "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1") {
                Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1" -wa SilentlyContinue
            }
            if (Test-Path "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1") {
                Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
            }
            elseif (Test-Path "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1") {
                Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
            }
            if (Test-Path "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.psd1") {
                Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.psd1" -wa SilentlyContinue
            }
            elseif (Test-Path "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.dll") {
                Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.dll" -wa SilentlyContinue
            }
            if (Test-Path "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1") {
                Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1" -wa SilentlyContinue
            }
        }
        else {
            $roleTailoredClientFolder = ""
            $NavIde = ""
            if (Test-Path "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1") {
                Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
            }
            elseif (Test-Path "$serviceTierFolder\Management\Microsoft.Dynamics.Nav.Apps.Management.psd1") {
                Import-Module "$serviceTierFolder\Management\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
            }
        }
    }

    cd "c:\run"
    if (!$silent) {
        if ($NavIde) {
            Write-Host -ForegroundColor Green "Welcome to the NAV Container PowerShell prompt"
        }
        else {
            Write-Host -ForegroundColor Green "Welcome to the Business Central Container PowerShell prompt"
        }
        Write-Host
    }
}