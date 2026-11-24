param(
    [Parameter(Mandatory = $true)]
    [AllowNull()]
    [AllowEmptyCollection()]
    [string[]]$Digests, # $digests = $env:digestsJson | ConvertFrom-Json
    [Parameter(Mandatory = $false)]
    [string]$PushRegistry = "mcrbusinesscentral.azurecr.io",
    [Parameter(Mandatory = $false)]
    [switch]$ProtectProductionTags
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
if ($LASTEXITCODE -ne 0) {
    throw "Failed to log in to $PushRegistry"
}

if ($ProtectProductionTags) {
    # Read ACR, not its potentially delayed MCR mirror, while the publisher holds the lock.
    $productionDigests = @('ltsc2016', 'ltsc2019', 'ltsc2022', 'ltsc2025') | ForEach-Object {
        "$_"; "$_-filesonly"
    } | ForEach-Object {
        $tag = $_
        $digestJson = az acr repository show --name $PushRegistry.Split('.')[0] --image "public/businesscentral:$tag" --query digest --output json --only-show-errors
        if ($LASTEXITCODE -ne 0) {
            throw "Could not inspect production tag $tag in $PushRegistry (exit code $LASTEXITCODE)"
        }
        $digest = ($digestJson -join '') | ConvertFrom-Json -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($digest)) {
            throw "Production tag $tag in $PushRegistry has no digest"
        }
        $digest
    }
    $Digests = @($Digests | Where-Object { $productionDigests -notcontains $_ })
    if (-not $Digests) {
        Write-Host "No unreferenced digests to mark as stale"
        return
    }
}

$staleDate = [System.DateTime]::Today.AddDays(-1).ToString('yyyy-MM-dd')
foreach ($digest in $Digests) {
    $image = "$PushRegistry/public/businesscentral@$digest"
    Write-Host "Stale $image on $staleDate"
    oras attach --artifact-type application/vnd.microsoft.artifact.lifecycle --annotation "vnd.microsoft.artifact.lifecycle.end-of-life.date=$staleDate" $image
}