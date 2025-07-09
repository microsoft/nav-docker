param(
    [Parameter(Mandatory = $true)]
    [string]$Digests, # $digests = $env:digestsJson | ConvertFrom-Json
    [Parameter(Mandatory = $false)]
    [string]$PushRegistry = "mcrbusinesscentral.azurecr.io"
)

if (-not (Get-Command -name "oras" -ErrorAction SilentlyContinue)) {
    throw "Please install the ORAS CLI before running this script e.g. via 'winget install oras-cli' or 'choco install oras-cli'"
}

az acr login --name $PushRegistry

$staleDate = [System.DateTime]::Today.AddDays(-1).ToString('yyyy-MM-dd')
foreach ($digest in $Digests) {
    $image = "$PushRegistry/public/businesscentral@$digest"
    Write-Host "Stale $image on $staleDate"
    oras attach --artifact-type application/vnd.microsoft.artifact.lifecycle --annotation "vnd.microsoft.artifact.lifecycle.end-of-life.date=$staleDate" $image
}