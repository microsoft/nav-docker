# Changes to Web Client configuration

if ($isBcSandbox) {
    write-Host "Enabling Financials User Experience"
    $wwwRootPath = Get-WWWRootPath
    $navsettingsFile = Join-Path $wwwRootPath "$webServerInstance\navsettings.json"
    $config = Get-Content $navSettingsFile | ConvertFrom-Json
    Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "DefaultApplicationId" -NotePropertyValue "true" -ErrorAction SilentlyContinue
    $config.NAVWebSettings.DefaultApplicationId = "FIN"
    Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "Designer" -NotePropertyValue "true" -ErrorAction SilentlyContinue
    $config.NAVWebSettings.Designer = $true
    $config | ConvertTo-Json | set-content $navSettingsFile
}

