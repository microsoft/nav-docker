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
    $adminFolder = Join-Path $serviceTierFolder 'Admin'
    $bcMgmtPsd1  = Join-Path $adminFolder 'Microsoft.BusinessCentral.Management.psd1'
    $bcAppsPsd1  = Join-Path $adminFolder 'Microsoft.BusinessCentral.Apps.Management.psd1'

    # The pure-PowerShell admin modules ship from BC v29 onwards and work in BOTH
    # Windows PowerShell 5.1 and PowerShell 7
    $usePurePsModules = $false
    if (Test-Path $bcMgmtPsd1) {
        $platformVersion = [System.Version](Import-PowerShellDataFile $bcMgmtPsd1).ModuleVersion
        $usePurePsModules = ($platformVersion.Major -ge 29)
    }

    if ($usePurePsModules) {
        # Preferred path -- identical for PS 5.1 and PS 7, full cmdlet parity
        ImportModule $bcMgmtPsd1
        ImportModule $bcAppsPsd1
        if ($isPsCore) {
            if (Test-Path 'c:\run\my\pscoreoverrides.ps1') {
                . 'c:\run\my\pscoreoverrides.ps1'
            }
            elseif (Test-Path 'c:\run\pscoreoverrides.ps1') {
                . 'c:\run\pscoreoverrides.ps1'
            }
        }
    }
    elseif ($isPsCore -and (Test-Path $adminFolder)) {
        ImportModule "$serviceTierFolder\Admin\Microsoft.Dynamics.Nav.Management.psm1"
        ImportModule "$serviceTierFolder\Admin\Microsoft.BusinessCentral.Management.psd1"
        ImportModule "$serviceTierFolder\Admin\Microsoft.BusinessCentral.Apps.Management.dll"
        if (Test-Path 'c:\run\my\pscoreoverrides.ps1') {
            . 'c:\run\my\pscoreoverrides.ps1'
        }
        else {
            . 'c:\run\pscoreoverrides.ps1'
        }
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