Write-Host "FilesOnly=$env:filesOnly"
Write-Host "only24=$env:only24"
$filesonly = $env:filesonly -eq 'true'
$only24 = $env:only24 -eq 'true'
if (-not $filesonly) {
    # Docker stages the module in the pwsh-only path so PS 5.1 keeps resolving SQLPS.
    $manifestPath = 'C:\Program Files\PowerShell\Modules\SqlServer\22.2.0\SqlServer.psd1'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'The staged SqlServer 22.2.0 module is missing.'
    }

    Write-Host 'Verifying SqlServer 22.2.0 module loads in PowerShell 7'
    pwsh -NoProfile -Command 'Import-Module -Name SqlServer -RequiredVersion 22.2.0 -ErrorAction Stop'
    if ($LASTEXITCODE -ne 0) {
        throw "SqlServer module 22.2.0 failed to import in PowerShell 7 (pwsh exit $LASTEXITCODE)"
    }

    Write-Host 'Done'
}
