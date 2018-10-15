$countryurl = "https://bcdocker.blob.core.windows.net/public/dk.zip"
$acr = "navgeneric"

$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
$country = "dk"

az acr run --registry $acr --file build-and-push.yaml --set baseimage=navgeneric.azurecr.io/nav:cb1g-w1 --set countryurl=$countryurl --set country=$country --set created=$created --os Windows --no-wait $PSScriptRoot

#"1803","1709","ltsc2016" | ForEach-Object {
#
#    #$baseimage = "microsoft/dynamics-nav:generic-dev-$_"
#    $baseimage = "$acr.azurecr.io/generic:1803"
#    az acr build --registry $acr `
#                 --image "nav:2017-cu18-w1-$_" `
#                 --timeout 4800 `
#                 --os Windows `
#                 --build-arg baseimage=$baseimage `
#                 --build-arg navdvdurl=$navdvdurl `
#                 --build-arg legal=$legal `
#                 --build-arg created=$created `
#                 --build-arg nav=$nav `
#                 --build-arg cu=$cu `
#                 --build-arg country=$country `
#                 --build-arg version=$version `
#                 --file DOCKERFILE `
#                 --verbose `
#                 https://github.com/Microsoft/nav-docker.git#master:specific
#}
