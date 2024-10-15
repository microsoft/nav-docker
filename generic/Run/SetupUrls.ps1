$sql2019url = 'https://aka.ms/bcdocker-Sql2019Url'

# https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates#latest-updates-available-for-currently-supported-versions-of-sql-server
# Click the link under latest cumulative update including the latest GDR update (NOT the link under latest GDR)
# In the KB article, click Method 3: Microsoft Download Center -> Download Pakcage now -> Download and right click "click here to download manually" -> Copy link address
# The file is around 900Mb (GDR update alone is smaller)
$sql2019LatestCuUrl = 'https://aka.ms/bcdocker-Sql2019LatestCuUrl'

# https://dotnet.microsoft.com/en-us/download/dotnet/6.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet6url = 'https://aka.ms/bcdocker-DotNet6Url'

# https://dotnet.microsoft.com/en-us/download/dotnet/8.0 - grab the direct link behind ASP.NET Core Runtime Windows -> Hosting Bundle
$dotNet8url = 'https://aka.ms/bcdocker-DotNet8Url'

# https://github.com/PowerShell/PowerShell/releases - grab the latest PowerShell-7.4.x-win-x64.msi link
$powerShell7url = 'https://aka.ms/bcdocker-PowerShell7Url'

# Misc URLs
$rewriteUrl = 'https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi'
$sqlncliUrl = 'https://download.microsoft.com/download/B/E/D/BED73AAC-3C8A-43F5-AF4F-EB4FEA6C8F3A/ENU/x64/sqlncli.msi'
$vcredist_x86url = 'https://aka.ms/highdpimfc2013x86enu'
$vcredist_x64url = 'https://aka.ms/highdpimfc2013x64enu'
$vcredist_x64_140url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'

# NAV/BC Docker Install Files
$navDockerInstallUrl = 'https://bcartifacts.blob.core.windows.net/prerequisites/nav-docker-install.zip'
$openXmlSdkV25url = 'https://bcartifacts.blob.core.windows.net/prerequisites/OpenXMLSDKv25.msi'
