Write-Host "FilesOnly=$env:filesOnly"
Write-Host "only24=$env:only24"
$filesonly = $env:filesonly -eq 'true'
$only24 = $env:only24 -eq 'true'
if (-not $filesonly) {
    Write-Host 'Installing SqlServer Module in Windows PowerShell'
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name SqlServer -RequiredVersion 22.2.0 -Scope AllUsers -Force -AllowClobber

    Write-Host 'Verifying SqlServer module loads in PowerShell 7'
    pwsh -NoProfile -Command 'Import-Module -Name SqlServer -RequiredVersion 22.2.0 -ErrorAction Stop'
    if ($LASTEXITCODE -ne 0) {
        throw "SqlServer module 22.2.0 failed to import in PowerShell 7 (pwsh exit $LASTEXITCODE)"
    }

    Write-Host 'Done'
}
