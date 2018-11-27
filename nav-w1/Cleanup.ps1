Param( 
    $context,
    [PSCustomObject] $json )

# Json usage:
#
# $json = '{
#     "blobcontainer":  "<blobcontainer>",
#     "navdvdblobname":  "<blobname>",
#     "vsixblobname":  "<blobname>"
# }' | ConvertFrom-Json

Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.navdvdblobname -Force -ErrorAction Ignore
if ($json.vsixblobname) {
    Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.vsixblobname -Force -ErrorAction Ignore
}
