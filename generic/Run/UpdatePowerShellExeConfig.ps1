$newConfigFile = Join-Path $PSScriptRoot "powershell.exe.config"
if (Test-Path $newConfigFile) {
    "C:\Windows\SysWOW64\WindowsPowerShell\v1.0\PowerShell.exe.config","C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe.config" | % {
        $existingConfigFile = $_
        if (Test-Path -Path $existingConfigFile) {
            $Acl = Get-Acl $existingConfigFile
            $Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("BUILTIN\Administrators","FullControl","Allow")
            $Acl.AddAccessRule($Ar)
            Set-Acl $existingConfigFile $Acl
            [xml]$existing = Get-Content -Path $existingConfigFile
            [xml]$new = Get-Content -Path $newConfigFile
            $existing.configuration.AppendChild($existing.ImportNode($new.configuration.runtime,$true)) | Out-Null
            $existing.Save($existingConfigFile)
        } else {
            Copy-Item -Path $newConfigFile -Destination $existingConfigFile -Force
        }
    }
}
