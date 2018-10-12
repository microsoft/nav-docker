$tag = "0.0.7.0"
$created = [DateTime]::Now.ToUniversalTime().ToString("yyyyMMddHHmm")

$acr = "navgeneric"

"1803","1709","ltsc2016" | ForEach-Object {
    az acr build --registry $acr `
                 --image "generic:$_" `
                 --timeout 4800 `
                 --os Windows `
                 --build-arg created=$created `
                 --build-arg tag=$tag `
                 --verbose `
                 --file "$_.DOCKERFILE" `
                 https://github.com/Microsoft/nav-docker.git#master
}
