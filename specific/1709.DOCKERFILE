FROM navgeneric.azurecr.io/generic:1709

ARG NAVDVDURL="" VSIXURL="" IsBcSandbox="N"

ENV DatabaseServer=localhost DatabaseInstance=SQLEXPRESS DatabaseName=CRONUS IsBcSandbox=$IsBcSandbox

RUN .\Run\buildimage.ps1 -NAVDVDURL $NAVDVDURL -VSIXURL $VSIXURL
