Write-Host "FilesOnly=$env:filesOnly"
Write-Host "only24=$env:only24"
$filesonly = $env:filesonly -eq 'true'
$only24 = $env:only24 -eq 'true'
if (-not $filesonly) {
    Write-Host 'Installing SqlServer Module in PowerShell 7'
    pwsh -Command 'Install-Module -Name SqlServer -RequiredVersion 22.2.0 -Scope AllUsers -Force'
    Write-Host 'Done'
}
