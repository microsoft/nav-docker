param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyCollection()]
    [string[]]$Digests, # $digests = $env:digestsJson | ConvertFrom-Json
    [Parameter(Mandatory = $false)]
    [string]$PushRegistry = "mcrbusinesscentral.azurecr.io"
)

if (-not $Digests) {
    Write-Host "No digests to mark as stale"
    return
}

if (-not (Get-Command -name "oras" -ErrorAction SilentlyContinue)) {
    $version = "1.2.0"
    $filename = Join-Path $env:TEMP "oras_$($version)_windows_amd64.zip"
    $orasPath = Join-Path $env:TEMP "oras"
    Write-Host "Installing ORAS CLI v$version..."
    Invoke-RestMethod -Method GET -UseBasicParsing -Uri "https://github.com/oras-project/oras/releases/download/v$($version)/oras_$($version)_windows_amd64.zip" -OutFile $filename
    Expand-Archive -Path $filename -DestinationPath $orasPath -Force
    $env:PATH = "$orasPath;$env:PATH"
}

az acr login --name $PushRegistry

$staleDate = [System.DateTime]::Today.AddDays(-1).ToString('yyyy-MM-dd')
foreach ($digest in $Digests) {
    $image = "$PushRegistry/public/businesscentral@$digest"
    Write-Host "Stale $image on $staleDate"
    oras attach --artifact-type application/vnd.microsoft.artifact.lifecycle --annotation "vnd.microsoft.artifact.lifecycle.end-of-life.date=$staleDate" $image
}