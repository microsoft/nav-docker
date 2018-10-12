$navdvdurl = "https://bcdocker.blob.core.windows.net/public/NAV.10.0.21832.W1.DVD.zip"
$acr = "nav2017"

#"1803","1709","ltsc2016" | ForEach-Object {
"1803" | ForEach-Object {
    $baseimage = "microsoft/dynamics-nav:generic-$_"
    az acr build --registry $acr `
                 --image "nav:2017-cu18-w1-$_" `
                 --timeout 4800 `
                 --os Windows `
                 --build-arg baseimage=$baseimage `
                 --build-arg NAVDVDURL=$navdvdurl `
                 --file DOCKERFILE `
                 --verbose `
                 https://github.com/Microsoft/nav-docker.git#master:specific
}
