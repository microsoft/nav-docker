if ((Get-service -name 'MicrosoftDynamicsNavServer$NAV').Status -eq 'Running') {
    exit 0
}
exit 1
