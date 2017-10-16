function Get-PlainSecurePassword
(
    [object]$key,
    [string]$encryptedPwd = ''    
)
{
    if ($encryptedPwd -eq "") { $encryptedPwd   = "$env:passwordencrypted" }
    $passSec        = ConvertTo-SecureString $encryptedPwd -Key $Key
    [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passSec))
}
function Get-SecurePassword
(
    [string]$KeyPath,
    [string]$encryptedPwd = ''    
)
{
    $key            = ((Get-Content $KeyPath) | ConvertFrom-Json)
    if ($encryptedPwd -eq "") { $encryptedPwd   = "$env:passwordencrypted" }
    ConvertTo-SecureString $encryptedPwd -Key $Key
}

function New-SecureKey
(
    [string]$KeyPath    
)
{
    $Key  = [System.Collections.ArrayList]@()
    $rnd  = [System.Random]::new()
    foreach ($item in (1..16)) { $Key.Add($rnd.Next(1, 256)) | Out-Null }
    $json = ($Key | ConvertTo-Json)
    Set-Content $KeyPath $json
}

function Get-SecureKey
(
    [string]$KeyPath
)
{
    ((Get-Content $KeyPath) | ConvertFrom-Json)
}

function New-SecurePassword
(
    [string]$KeyPath    
)
{
    $key     = ((Get-Content $KeyPath) | ConvertFrom-Json)
    $passSec = Read-Host 'Input the user`s password' -AsSecureString
    (ConvertFrom-SecureString $passSec -Key $Key)
}