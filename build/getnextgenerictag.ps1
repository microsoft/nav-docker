param(
    [Parameter(Mandatory = $true)]
    [System.Version]$GenericTag,
    [Parameter(Mandatory = $true)]
    [string]$PushRegistry
)

$ErrorActionPreference = 'Stop'
$tagsJson = az acr repository show-tags --name $PushRegistry.Split('.')[0] --repository public/businesscentral --output json --only-show-errors
if ($LASTEXITCODE -ne 0) {
    throw "Could not list published tags in $PushRegistry (exit code $LASTEXITCODE)"
}
$tagsText = ($tagsJson -join '').Trim()
if (-not $tagsText.StartsWith('[')) {
    throw "No tag list returned by $PushRegistry"
}
$tags = $tagsText | ConvertFrom-Json -ErrorAction Stop

$prefix = "$($GenericTag.Major).$($GenericTag.Minor).$($GenericTag.Build)."
$escapedPrefix = [regex]::Escape($prefix)
[int]$revision = 0
foreach ($tag in $tags) {
    if ($tag -match "^\d+\.\d+\.\d+\.\d+-$escapedPrefix(\d+)(-|$)") {
        $revision = [Math]::Max($revision, [int]$Matches[1] + 1)
    }
}

return "$prefix$revision"
