$acr = "navgeneric"
$baseimage = "microsoft/dynamics-nav:generic"
$navdvdurl = "https://bcdocker.blob.core.windows.net/public/NAV.10.0.21832.W1.DVD.zip"
$legal = "http://go.microsoft.com/fwlink/?LinkId=724017"
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")
$nav = "2017"
$cu = "cu18"
$country = "w1"
$version = "10.0.21832.0"

#az acr run --registry $acr `
#           --set baseimage=$baseimage `
#           --set navdvdurl=$navdvdurl `
#           --set legal=$legal `
#           --set created=$created `
#           --set nav=$nav `
#           --set cu=$cu `
#           --set country=$country `
#           --set version=$version `
#           --timeout 10800 `
#           --os Windows `
#           --no-wait `
#           --file build-and-push.yaml `
#           https://github.com/Microsoft/nav-docker.git#master:nav-w1


#"1803","1709","ltsc2016" | ForEach-Object {
"ltsc2016" | ForEach-Object {
    if ($_ -eq "ltsc2016") {
        $thisbaseimage = $baseimage
    } else {
        $thisbaseimage = "$baseimage-$_"
    }
    az acr build --registry $acr `
                 --image "nav:$nav-$cu-$country-$_" `
                 --build-arg baseimage=$thisbaseimage `
                 --build-arg navdvdurl=$navdvdurl `
                 --build-arg legal=$legal `
                 --build-arg created=$created `
                 --build-arg nav=$nav `
                 --build-arg cu=$cu `
                 --build-arg country=$country `
                 --build-arg version=$version `
                 --timeout 10800 `
                 --os Windows `
                 --no-logs `
                 --file DOCKERFILE `
                 https://github.com/Microsoft/nav-docker.git#master:nav-w1
}
