try {
    . (Join-Path $PSScriptRoot "ServiceSettings.ps1")
    $CustomConfigFile = Join-Path (Get-Item "C:\Program Files\Microsoft Dynamics NAV\*\Service").FullName "CustomSettings.config"
    $CustomConfig = [xml](Get-Content $CustomConfigFile)
    $publicWebBaseUrl = $CustomConfig.SelectSingleNode("//appSettings/add[@key='PublicWebBaseUrl']").Value
    if ($publicWebBaseUrl -ne "" -or "$env:healthCheckBaseUrl" -ne "") {
        # WebClient installed use WebClient base Health endpoint
        $healthCheckBaseUrl = $publicWebBaseUrl
        if ("$env:healthCheckBaseUrl" -ne "") { $healthCheckBaseUrl = "$env:healthCheckBaseUrl" }
        if (!($healthCheckBaseUrl.EndsWith("/"))) { $healthCheckBaseUrl += "/" }
        if ($healthCheckBaseUrl.StartsWith("https")) {
            if (-not("dummy" -as [type])) {
                add-type -TypeDefinition @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public static class Dummy {
    public static bool ReturnTrue(object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors) { return true; }
    public static RemoteCertificateValidationCallback GetDelegate() {
        return new RemoteCertificateValidationCallback(Dummy.ReturnTrue);
    }
}
"@
            }
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [dummy]::GetDelegate()
        }
        $result = Invoke-WebRequest -Uri "${healthCheckBaseUrl}Health/System" -UseBasicParsing -TimeoutSec 10
        if ($result.StatusCode -eq 200 -and ((ConvertFrom-Json $result.Content).result)) {
            # Web Client Health Check Endpoint will test Web Client, Service Tier and Database Connection
            exit 0
        }
    } else {
        # WebClient not installed, check Service Tier
        if ((Get-service -name "$NavServiceName").Status -eq 'Running') {
            exit 0
        }
    }
} catch {
}
exit 1