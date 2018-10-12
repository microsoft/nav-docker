FROM microsoft/dynamics-nav:generic-1803

ARG NAVDVDURL="" VSIXURL="" IsBcSandbox="N"

ENV DatabaseServer=localhost DatabaseInstance=SQLEXPRESS DatabaseName=CRONUS IsBcSandbox=$IsBcSandbox

RUN .\Run\buildimage.ps1 -NAVDVDURL $NAVDVDURL -VSIXURL $VSIXURL
