$wwwRootPath = Get-WWWRootPath
$webConfigFile = Join-Path $wwwRootPath "$webServerInstance\web.config"
$webconfig = Get-Content -Path $webConfigFile -Raw -Encoding UTF8
$webConfig = $webconfig.Replace('<!-- <rewrite>','<rewrite>').Replace('</rewrite> -->','</rewrite>').Replace('{R:0}?tenant={C:1}','{R:0}?tenant=default')
Set-Content -Path $webConfigFile -Value $webconfig -Encoding UTF8
. 'C:\run\SetupWebConfiguration.ps1'