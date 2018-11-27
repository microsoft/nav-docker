Param( 
    $context,
    [PSCustomObject] $json )

# Json usage:
#
# $json = '{
#     "blobcontainer":  "<blobcontainer>",
#     "countryblobname":  "<blobname>",
# }' | ConvertFrom-Json

Remove-AzureStorageBlob -Context $context -Container $json.blobcontainer -Blob $json.countryblobname -Force -ErrorAction SilentlyContinue
