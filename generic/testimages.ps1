$tags = @(
"10.0.14393.2906-generic-0.1.0.7"
"10.0.17763.437-generic-0.1.0.7"
"10.0.18362.116-generic-0.1.0.7"

"10.0.14393.2972-generic-0.1.0.7"
"10.0.17763.504-generic-0.1.0.7"
"10.0.18362.175-generic-0.1.0.7"

"10.0.14393.3025-generic-0.1.0.7"
"10.0.17763.557-generic-0.1.0.7"
"10.0.18362.239-generic-0.1.0.7"

"10.0.14393.3085-generic-0.1.0.7"
"10.0.17763.615-generic-0.1.0.7"
"10.0.18362.295-generic-0.1.0.7"

"10.0.14393.3144-generic-0.1.0.7"
"10.0.17763.678-generic-0.1.0.7"
"10.0.18362.356-generic-0.1.0.7"

"10.0.14393.3204-generic-0.1.0.7"
"10.0.17763.737-generic-0.1.0.7"
"10.0.18362.476-generic-0.1.0.7"
"10.0.18363.476-generic-0.1.0.7"

"10.0.14393.3326-generic-0.1.0.7"
"10.0.17763.864-generic-0.1.0.7"
"10.0.18362.535-generic-0.1.0.7"
"10.0.18363.535-generic-0.1.0.7"

"10.0.14393.3384-generic-0.1.0.7"
"10.0.17763.914-generic-0.1.0.7"
"10.0.18362.592-generic-0.1.0.7"
"10.0.18363.592-generic-0.1.0.7"

"10.0.14393.3443-generic-0.1.0.7"
"10.0.17763.973-generic-0.1.0.7"
"10.0.18362.658-generic-0.1.0.7"
"10.0.18363.658-generic-0.1.0.7"

"10.0.14393.3506-generic-0.1.0.7"
"10.0.17763.1040-generic-0.1.0.7"
"10.0.18362.720-generic-0.1.0.7"
"10.0.18363.720-generic-0.1.0.7"

"10.0.14393.3630-generic-0.1.0.7"
"10.0.17763.1158-generic-0.1.0.7"
"10.0.18362.778-generic-0.1.0.7"
"10.0.18363.778-generic-0.1.0.7"

"10.0.14393.3686-generic-0.1.0.7"
"10.0.17763.1217-generic-0.1.0.7"
"10.0.18362.836-generic-0.1.0.7"
"10.0.18363.836-generic-0.1.0.7"
"10.0.19041.264-generic-0.1.0.7"

"10.0.14393.3750-generic-0.1.0.7"
"10.0.17763.1282-generic-0.1.0.7"
"10.0.18362.900-generic-0.1.0.7"
"10.0.18363.900-generic-0.1.0.7"
"10.0.19041.329-generic-0.1.0.7"

"10.0.14393.3808-generic-0.1.0.7"
"10.0.17763.1339-generic-0.1.0.7"
"10.0.18362.959-generic-0.1.0.7"
"10.0.18363.959-generic-0.1.0.7"
"10.0.19041.388-generic-0.1.0.7"
)

[Array]::Reverse($tags)

$tags | % {
    #$genericImage = "mcr.microsoft.com/dynamicsnav:$_" # .Replace("0.1.0.7", "0.1.0.8")
    $genericImage = "my:$_".Replace("0.1.0.7", "0.1.0.9")
    
    
    $artifactUrl = Get-BCArtifactUrl -type OnPrem -country w1
    $password = 'P@ssword1'
    $securePassword = ConvertTo-SecureString -String $password -AsPlainText -Force
    $credential = New-Object pscredential 'admin', $securePassword
    
    $parameters = @{
        "accept_eula"               = $true
        "containerName"             = "test"
        "artifactUrl"               = $artifactUrl
        "useGenericImage"           = $genericImage
        "auth"                      = "NAVUserPassword"
        "Credential"                = $credential
        "updateHosts"               = $true
        "doNotCheckHealth"          = $true
        "EnableTaskScheduler"       = $false
        "Isolation"                 = "hyperv"
        "MemoryLimit"               = "8G"
    }
    
    New-NavContainer @parameters
}