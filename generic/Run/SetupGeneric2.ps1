Write-Host 'Installing SqlServer Module in PowerShell 7'; \
pwsh -Command 'Install-Module -Name SqlServer -RequiredVersion 22.2.0 -Scope AllUsers -Force'; \
Write-Host 'Done'
