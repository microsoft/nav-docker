# INPUT
#     $httpPath
#     $runPath
#     $certificateCerFile (optional)
#     $servicesUseSSL (optional)
#
# OUTPUT
#

if ($certificateCerFile -and $servicesUseSSL) {
    Copy-Item -Path $certificateCerFile -Destination $httpPath
}
Copy-Item -Path "$runPath\*.vsix" -Destination $httpPath
