# Changes to Web Client configuration
if ($customWebSettings -ne "") {
    Write-Host "Modifying Web Client config with settings from environment variable"        
    $jsonConfigPath = "C:\inetpub\wwwroot\NAV\navsettings.json"
    $webConfigPath = "C:\inetpub\wwwroot\NAV\web.config"
    
    if (Test-Path $jsonConfigPath) {
        $jsonConfig = Get-Content $jsonConfigPath | ConvertFrom-Json
        $customWebSettingsArray = $customWebSettings -split ","
        foreach ($customWebSetting in $customWebSettingsArray) {
            $customWebSettingArray = $customWebSetting -split "="
            $customWebSettingKey = $customWebSettingArray[0]
            $customWebSettingValue = $customWebSettingArray[1]
            if ($jsonConfig.NAVWebSettings.$customWebSettingKey -eq $null) {
                Write-Host "Creating $customWebSettingKey and setting it to $customWebSettingValue"
                $jsonConfig.NAVWebSettings | Add-Member $customWebSettingKey $customWebSettingValue
            } else {
                Write-Host "Setting $customWebSettingKey to $customWebSettingValue"
                $jsonConfig.NAVWebSettings.$customWebSettingKey = $customWebSettingValue
            }
        }
        $jsonConfig | ConvertTo-Json | Set-Content $jsonConfigPath
    } elseif (Test-Path $webConfigPath) {
        $webConfig = [xml](Get-Content $webConfigPath)
        Set-ConfigSetting -customSettings $customWebSettings -parentPath "//configuration/DynamicsNAVSettings" -leafName "add" -customConfig $webConfig
        $webConfig.Save($webConfigPath)
    } else {
        Write-Host "Got an env param for changing the Web Client config, but didn't find a Web Client"
    }

}

