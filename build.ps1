. (Join-Path $PSScriptRoot "settings.ps1")
. (Join-Path $PSScriptRoot "BuildAndPushGeneric.ps1")

BuildAndPushGeneric -registry $registry `
                    -imageFolder $PSScriptRoot `
                    -windowsservercoreImage "microsoft/dotnet-framework:4.7.2-sdk-20180523-windowsservercore-ltsc2016" `
                    -tag $tag `
                    -silent $silent `
                    -removeImage $false `
                    -latest $latest `
                    -forceRebuild $true
