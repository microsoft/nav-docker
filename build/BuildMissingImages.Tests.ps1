BeforeAll {
    $repositoryRoot = Split-Path $PSScriptRoot -Parent
    $analyzeScript = Join-Path $PSScriptRoot 'analyzeimages.ps1'
    $buildScript = Join-Path $PSScriptRoot 'build.ps1'
    $nextTagScript = Join-Path $PSScriptRoot 'getnextgenerictag.ps1'
    $staleScript = Join-Path $PSScriptRoot 'markstale.ps1'

    function docker { throw 'Unexpected Docker command' }
    function az { throw 'Unexpected Azure CLI command' }
    function oras { throw 'Unexpected ORAS command' }
}

Describe 'Publishing revision allocation under the lock' {
    BeforeEach {
        $state = @{ Tags = '[]'; ExitCode = 0 }
        Mock az {
            $global:LASTEXITCODE = $state.ExitCode
            return $state.Tags
        }
    }

    It 'advances past tags published since the initial analysis, including suffix variants' {
        $state.Tags = '["10.0.20348.1-1.2.3.8","10.0.26100.1-1.2.3.10-filesonly","10.0.26100.1-1.2.4.99"]'

        & $nextTagScript -GenericTag '1.2.3.8' -PushRegistry 'test.azurecr.io' | Should -Be '1.2.3.11'

        $state.Tags = '["10.0.26100.1-1.2.3.11"]'
        & $nextTagScript -GenericTag '1.2.3.8' -PushRegistry 'test.azurecr.io' | Should -Be '1.2.3.12'
    }

    It 'allocates zero for an empty repository and one after a revision-zero publish' {
        & $nextTagScript -GenericTag '1.2.3.0' -PushRegistry 'test.azurecr.io' | Should -Be '1.2.3.0'

        $state.Tags = '["10.0.20348.1-1.2.3.0"]'
        & $nextTagScript -GenericTag '1.2.3.0' -PushRegistry 'test.azurecr.io' | Should -Be '1.2.3.1'
    }

    It 'fails closed when the registry lookup fails' {
        $state.ExitCode = 1

        { & $nextTagScript -GenericTag '1.2.3.8' -PushRegistry 'test.azurecr.io' } | Should -Throw '*Could not list published tags*'
    }

    It 'rejects a missing tag list rather than reusing revision zero' {
        $state.Tags = 'null'

        { & $nextTagScript -GenericTag '1.2.3.8' -PushRegistry 'test.azurecr.io' } | Should -Throw '*No tag list*'
    }
}

Describe 'Production digest protection at stale-marking time' {
    BeforeEach {
        $state = @{ FailedTag = ''; MissingDigestTag = '' }
        Mock Write-Host {}
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args -contains 'login') { return }
            $tag = $args[($args.IndexOf('--image') + 1)]
            if ($tag -eq $state.FailedTag) {
                $global:LASTEXITCODE = 1
                return
            }
            if ($tag -eq $state.MissingDigestTag) { return 'null' }
            if ($tag -eq 'public/businesscentral:ltsc2025-filesonly') {
                return '"sha256:promoted"'
            }
            return '"sha256:production"'
        }
        Mock oras { $global:LASTEXITCODE = 0 }
    }

    It 'excludes a candidate promoted after analysis while marking dev-only digests' {
        & $staleScript -Digests @('sha256:promoted', 'sha256:old-dev') -PushRegistry 'test.azurecr.io' -ProtectProductionTags

        Should -Invoke az -Times 8 -Exactly -ParameterFilter { $args -contains '--image' }
        Should -Invoke oras -Times 1 -Exactly
        Should -Invoke oras -Times 1 -Exactly -ParameterFilter { $args -contains 'test.azurecr.io/public/businesscentral@sha256:old-dev' }
    }

    It 'does not mark anything when every candidate is now referenced by production' {
        & $staleScript -Digests @('sha256:promoted') -PushRegistry 'test.azurecr.io' -ProtectProductionTags

        Should -Invoke oras -Times 0 -Exactly
    }

    It 'fails before marking any candidate if a production lookup fails' {
        $state.FailedTag = 'public/businesscentral:ltsc2025-filesonly'

        { & $staleScript -Digests @('sha256:old-dev') -PushRegistry 'test.azurecr.io' -ProtectProductionTags } | Should -Throw '*Could not inspect production tag*'

        Should -Invoke oras -Times 0 -Exactly
    }

    It 'fails before marking any candidate if a production digest is missing' {
        $state.MissingDigestTag = 'public/businesscentral:ltsc2025-filesonly'

        { & $staleScript -Digests @('sha256:old-dev') -PushRegistry 'test.azurecr.io' -ProtectProductionTags } | Should -Throw '*has no digest*'

        Should -Invoke oras -Times 0 -Exactly
    }

    It 'preserves existing callers that do not request production protection' {
        & $staleScript -Digests @('sha256:old-prod') -PushRegistry 'test.azurecr.io'

        Should -Invoke az -Times 0 -Exactly -ParameterFilter { $args -contains '--image' }
        Should -Invoke oras -Times 1 -Exactly
    }
}

Describe 'Image analysis manifest lookups' {
    BeforeEach {
        $originalOutput = $env:GITHUB_OUTPUT
        $env:GITHUB_OUTPUT = Join-Path $TestDrive 'outputs.txt'
        Remove-Item $env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
        $state = @{ FailedTag = ''; MissingDigestTag = '' }

        Mock Write-Host {}
        Mock docker {
            $global:LASTEXITCODE = 0
            $tag = ($args[2] -split ':')[-1]
            if ($tag -eq $state.FailedTag) {
                $global:LASTEXITCODE = 1
                return '{"Descriptor":{"digest":"sha256:shared"}}'
            }
            if ($tag -eq $state.MissingDigestTag) {
                return '{"Descriptor":{}}'
            }
            if ($tag -eq 'ltsc2016-dev' -or $tag -eq 'ltsc2016') {
                return '{"Descriptor":{"digest":"sha256:shared"}}'
            }
            return '{"Descriptor":{"digest":"sha256:unique-<tag>"}}'.Replace('<tag>', $tag)
        }
        Mock New-Object {
            $client = [pscustomobject]@{
                Headers = [System.Collections.Specialized.NameValueCollection]::new()
            }
            $client | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                param($Uri)
                if ($Uri -like '*/tags/list') {
                    return '{"tags":[]}'
                }
                return '{"history":[{"v1Compatibility":"{\"os.version\":\"10.0.20348.1\"}"}]}'
            }
            return $client
        } -ParameterFilter { $TypeName -eq 'System.Net.WebClient' }
    }

    AfterEach {
        $env:GITHUB_OUTPUT = $originalOutput
    }

    It 'stops without publishing stale candidates when a production lookup fails' {
        $state.FailedTag = 'ltsc2016'

        { & $analyzeScript -RevisionNumber 123 } | Should -Throw '*Could not inspect manifest for tag ltsc2016*'

        Test-Path $env:GITHUB_OUTPUT | Should -BeFalse
    }

    It 'stops without publishing stale candidates when a production digest is missing' {
        $state.MissingDigestTag = 'ltsc2016'

        { & $analyzeScript -RevisionNumber 123 } | Should -Throw '*has no digest*'

        Test-Path $env:GITHUB_OUTPUT | Should -BeFalse
    }

    It 'excludes shared production digests while preserving dev-only stale candidates' {
        & $analyzeScript -RevisionNumber 123

        $digestLine = Get-Content $env:GITHUB_OUTPUT | Where-Object { $_ -like 'digestsJson=*' }
        $digests = $digestLine.Substring('digestsJson='.Length) | ConvertFrom-Json
        $digests | Should -Not -Contain 'sha256:shared'
        $digests | Should -Contain 'sha256:unique-ltsc2019-dev'
        @($digests).Count | Should -Be 7
    }
}

Describe 'Separate build and publication' {
    BeforeEach {
        Push-Location $repositoryRoot
        $state = @{
            AzureAuthenticated = $false
            PublishedTags = '[]'
            TagLookupExitCode = 0
        }
        $buildParameters = @{
            BaseImage = 'mcr.microsoft.com/dotnet/framework/runtime:4.8.1-windowsservercore-ltsc2022'
            LtscTag = 'ltsc2022'
            FilesOnly = $false
            Only24 = $false
            GenericTag = '1.2.3.4'
        }

        Mock Write-Host {}
        Mock Out-Host {}
        Mock docker {
            $global:LASTEXITCODE = 0
            switch ($args[0]) {
                'pull' {}
                'inspect' { return '{"OsVersion":"10.0.20348.1"}' }
                'build' {
                    $state.AzureAuthenticated = $false
                    return 'Successfully built test-image'
                }
                'tag' {}
                'push' {}
                default { throw "Unexpected Docker command: $args" }
            }
        }
        Mock az {
            if (-not $state.AzureAuthenticated) {
                throw 'Azure session expired'
            }
            $global:LASTEXITCODE = 0
            if ($args -contains 'show-tags') {
                $global:LASTEXITCODE = $state.TagLookupExitCode
                return $state.PublishedTags
            }
        }
    }

    AfterEach {
        Pop-Location
    }

    It 'builds without Azure and publishes after fresh authentication without rebuilding' {
        $image = & $buildScript @buildParameters
        $image | Should -Be 'my:10.0.20348.1-1.2.3.4'
        Should -Invoke az -Times 0 -Exactly
        Should -Invoke docker -Times 0 -Exactly -ParameterFilter { $args[0] -eq 'push' }

        $state.AzureAuthenticated = $true
        & $buildScript @buildParameters -PublishOnly -PushToDev -PushToProd

        Should -Invoke docker -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'build' }
        Should -Invoke docker -Times 1 -Exactly -ParameterFilter { $args[0] -eq 'pull' }
        Should -Invoke az -Times 1 -Exactly -ParameterFilter { $args -contains 'show-tags' }
        Should -Invoke docker -Times 5 -Exactly -ParameterFilter { $args[0] -eq 'push' }
        Should -Invoke docker -Times 1 -Exactly -ParameterFilter {
            $args[0] -eq 'push' -and $args[1] -eq 'mcrbusinesscentral.azurecr.io/public/businesscentral:10.0.20348.1-1.2.3.4'
        }
    }

    It 'refuses publication when the actual versioned tag already exists' {
        $state.AzureAuthenticated = $true
        $state.PublishedTags = '["10.0.20348.1-1.2.3.4"]'

        { & $buildScript @buildParameters -PublishOnly -PushToProd } | Should -Throw '*already exists*'

        Should -Invoke docker -Times 0 -Exactly -ParameterFilter { $args[0] -eq 'push' }
    }

    It 'refuses publication when the authenticated tag lookup fails' {
        $state.AzureAuthenticated = $true
        $state.TagLookupExitCode = 1

        { & $buildScript @buildParameters -PublishOnly -PushToProd } | Should -Throw '*Could not list tags*'

        Should -Invoke docker -Times 0 -Exactly -ParameterFilter { $args[0] -eq 'push' }
    }
}

Describe 'Staged SqlServer container setup' {
    BeforeAll {
        function pwsh { throw 'Unexpected pwsh command' }
        $setupScript = Join-Path $repositoryRoot 'generic\Run\SetupGeneric2.ps1'
    }

    BeforeEach {
        $originalFilesOnly = $env:filesonly
        $originalOnly24 = $env:only24
        $env:filesonly = 'false'
        $env:only24 = 'false'
        Mock Write-Host {}
        Mock Test-Path { return $true }
        Mock pwsh { $global:LASTEXITCODE = 0 }
        Mock Save-Module { throw 'Unexpected gallery access in the container' }
    }

    AfterEach {
        $env:filesonly = $originalFilesOnly
        $env:only24 = $originalOnly24
    }

    It 'verifies the staged module in PowerShell 7 without changing PS5 module resolution' {
        $modulePathBefore = $env:PSModulePath
        & $setupScript

        Should -Invoke pwsh -Times 1 -Exactly -ParameterFilter {
            $args -contains 'Import-Module -Name SqlServer -RequiredVersion 22.2.0 -ErrorAction Stop'
        }
        $env:PSModulePath | Should -Be $modulePathBefore
        Should -Invoke Save-Module -Times 0 -Exactly
    }

    It 'fails if the staged module is absent' {
        Mock Test-Path { return $false }

        { & $setupScript } | Should -Throw '*staged SqlServer 22.2.0 module is missing*'
        Should -Invoke pwsh -Times 0 -Exactly
    }

    It 'fails if PowerShell 7 cannot import the staged module' {
        Mock pwsh { $global:LASTEXITCODE = 1 }

        { & $setupScript } | Should -Throw '*failed to import*'
    }

    It 'does not require or import SqlServer in files-only setup' {
        $env:filesonly = 'true'
        & $setupScript

        Should -Invoke Test-Path -Times 0 -Exactly
        Should -Invoke pwsh -Times 0 -Exactly
    }
}
