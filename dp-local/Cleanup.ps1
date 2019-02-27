Param( 
    $context,
    [PSCustomObject] $json )

# Json usage:
#
# $json = '{
#     "blobcontainer":  "<blobcontainer>",
#     "devpreviewblobname":  "<blobname>"
# }' | ConvertFrom-Json

if ($json.devpreviewblobname) {
    Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.devpreviewblobname -Force -ErrorAction Ignore
}
