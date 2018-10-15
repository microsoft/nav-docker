$navdvdurl = "https://bcdocker.blob.core.windows.net/public/NAV.10.0.21832.W1.DVD.zip"
#$acr = "nav2016"
$acr = "navgeneric"

$legal = "http://go.microsoft.com/fwlink/?LinkId=724017"
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
$nav = "2017"
$cu = "cu18"
$country = "w1"
$version = "10.0.21832.0"
$imagetag = "$version-$country"

az acr run --registry $acr --file build-and-push.yaml --set tag=$imagetag --set baseimage=microsoft/dynamics-nav:generic-dev --set navdvdurl=$navdvdurl --set legal=$legal --set created=$created --set nav=$nav --set cu=$cu --set country=$country --set version=$version --os Windows $PSScriptRoot

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
