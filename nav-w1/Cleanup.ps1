Param( 
    $context,
    [PSCustomObject] $json )

# Json usage:
#
# $json = '{
#     "blobcontainer":  "<blobcontainer>",
#     "navdvdblobname":  "<blobname>",
#     "vsixblobname":  "<blobname>",
# }' | ConvertFrom-Json

Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.navdvdblobname -Force -ErrorAction SilentlyContinue
Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.vsixblobname -Force -ErrorAction SilentlyContinue
