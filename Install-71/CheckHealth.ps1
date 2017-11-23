if ((Get-service -name 'MicrosoftDynamicsNavServer$NAV').Status -eq 'Running') {
    exit 0
}