# INPUT
#     $runPath
#     $serviceTierFolder
#     $roleTailoredClientFolder
#
# OUTPUT
#

$AddinsFolder = (Join-Path $runPath "Add-ins")
if (Test-Path $AddinsFolder -PathType Container) {
    copy-item -Path (Join-Path $AddinsFolder "*") -Destination (Join-Path $serviceTierFolder "Add-ins") -Recurse
    if ($roleTailoredClientFolder -and (Test-Path (Join-Path $roleTailoredClientFolder "Add-ins"))) {
        copy-item -Path (Join-Path $AddinsFolder "*") -Destination (Join-Path $roleTailoredClientFolder "Add-ins") -Recurse
    }
}
