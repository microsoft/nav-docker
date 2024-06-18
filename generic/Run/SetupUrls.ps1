throw "SETUPURLS.PS1 WAS NOT OVERRIDDEN WITH URLs from variables"

$sql2019url = 'https://go.microsoft.com/fwlink/p/?linkid=866658'

# https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/build-versions
# https://www.microsoft.com/en-us/download/details.aspx?id=100809
$sql2019LatestCuUrl = 'https://download.microsoft.com/download/6/e/7/6e72dddf-dfa4-4889-bc3d-e5d3a0fd11ce/SQLServer2019-KB5037331-x64.exe'

# https://dotnet.microsoft.com/en-us/download/dotnet/6.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet6url = 'https://download.visualstudio.microsoft.com/download/pr/fee6ce1d-a3c4-4aed-ba11-5cbb9e22e5b1/8b1248f13ca5326850112ad45ccf3527/dotnet-hosting-6.0.31-win.exee'

# https://dotnet.microsoft.com/en-us/download/dotnet/8.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet8url = 'https://download.visualstudio.microsoft.com/download/pr/751d3fcd-72db-4da2-b8d0-709c19442225/33cc492bde704bfd6d70a2b9109005a0/dotnet-hosting-8.0.6-win.exe'

# https://github.com/PowerShell/PowerShell/releases - grab the latest PowerShell-7.4.x-win-x64.msi link
$powerShell7url = 'https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/PowerShell-7.4.2-win-x64.msi'

# Misc URLs
$rewriteUrl = 'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi'
$sqlncliUrl = 'https://download.microsoft.com/download/B/E/D/BED73AAC-3C8A-43F5-AF4F-EB4FEA6C8F3A/ENU/x64/sqlncli.msi'
$vcredist_x86url = 'https://aka.ms/highdpimfc2013x86enu'
$vcredist_x64url = 'https://aka.ms/highdpimfc2013x64enu'
$vcredist_x64_140url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'

# NAV/BC Docker Install Files
$navDockerInstallUrl = 'https://bcartifacts.blob.core.windows.net/prerequisites/nav-docker-install.zip'
$openXmlSdkV25url = 'https://bcartifacts.blob.core.windows.net/prerequisites/OpenXMLSDKv25.msi'
