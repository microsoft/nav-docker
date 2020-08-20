# Changes to Web Client configuration

if ($isBcSandbox -or $multitenant) {

    $wwwRootPath = Get-WWWRootPath
    if ($isBcSandbox) {
        write-Host "Enabling Financials User Experience"
        $navsettingsFile = Join-Path $wwwRootPath "$webServerInstance\navsettings.json"
        $config = Get-Content $navSettingsFile | ConvertFrom-Json
        Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "DefaultApplicationId" -NotePropertyValue "true" -ErrorAction SilentlyContinue
        $config.NAVWebSettings.DefaultApplicationId = "FIN"
        Add-Member -InputObject $config.NAVWebSettings -NotePropertyName "Designer" -NotePropertyValue "true" -ErrorAction SilentlyContinue
        $config.NAVWebSettings.Designer = $true
        $config | ConvertTo-Json | set-content $navSettingsFile
    }

    if ($multitenant) {
        $webConfigFile = Join-Path $wwwRootPath "$webServerInstance\web.config"
        try {
            $webConfig = [xml](Get-Content $webConfigFile)
            $webConfig.configuration.'system.webServer'.rewrite.rules.GetEnumerator() | % { 
                Write-Host "Enabling rewrite rule: $($_.Name)"
                $_.Enabled = "true"
            }
            $webConfig.Save($webConfigFile)
        }
        catch {}
    }
}

