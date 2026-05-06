Write-Host "FilesOnly=$env:filesOnly"
Write-Host "only24=$env:only24"
$filesonly = $env:filesonly -eq 'true'
$only24 = $env:only24 -eq 'true'
if (-not $filesonly) {
    Write-Host 'Installing SqlServer Module to PowerShell 7 modules path'
    # Server 2016 WinPS 5.1 defaults to TLS 1.0/1.1; PSGallery requires TLS 1.2+.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    # Save to the pwsh-only modules path so PS 5.1 keeps resolving Invoke-Sqlcmd to SQLPS
    # (avoids SqlServer 22's strict-SSL defaults breaking in-container localhost SQL connections).
    # Running from Windows PS 5.1 also avoids the pwsh 7.6 PowerShellGet AV crash on Server 2022.
    $pwshModulesPath = 'C:\Program Files\PowerShell\Modules'
    if (-not (Test-Path $pwshModulesPath)) {
        New-Item -ItemType Directory -Path $pwshModulesPath -Force | Out-Null
    }
    Save-Module -Name SqlServer -RequiredVersion 22.2.0 -Path $pwshModulesPath -Force

    Write-Host 'Verifying SqlServer module loads in PowerShell 7'
    pwsh -NoProfile -Command 'Import-Module -Name SqlServer -RequiredVersion 22.2.0 -ErrorAction Stop'
    if ($LASTEXITCODE -ne 0) {
        throw "SqlServer module 22.2.0 failed to import in PowerShell 7 (pwsh exit $LASTEXITCODE)"
    }

    Write-Host 'Done'
}
