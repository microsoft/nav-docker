if ((Test-Path "$PSScriptRoot\my" -PathType Container) -and (Test-Path "$PSScriptRoot\my\CheckHealth.ps1" -PathType Leaf)) {
    . "$PSScriptRoot\my\CheckHealth.ps1"
} else {
    . "$PSScriptRoot\CheckHealth.ps1"
}
