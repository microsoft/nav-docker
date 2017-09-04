$serviceTierFolder = (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName
$roleTailoredClientFolder = (Get-Item "C:\Program Files (x86)\Microsoft Dynamics NAV\*\RoleTailored Client").FullName

Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psm1" -wa SilentlyContinue
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1" -wa SilentlyContinue
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -wa SilentlyContinue
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Apps.Tools.psd1" -wa SilentlyContinue
Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Model.Tools.psd1" -wa SilentlyContinue

cd $PSScriptRoot
Write-Host -ForegroundColor Green "Welcome to the NAV Container PowerShell prompt"
Write-Host
