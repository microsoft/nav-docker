ARG baseimage

FROM $baseimage

ARG navdvdurl=""
ARG vsixurl=""
ARG legal=""
ARG created=""
ARG nav=""
ARG cu=""
ARG country=""
ARG version=""

ENV DatabaseServer=localhost DatabaseInstance=SQLEXPRESS DatabaseName=CRONUS NAVDVDURL=$navdvdurl VSIXURL=$vsixurl IsBcSandbox=N

COPY ./buildimage.ps1 /Run/buildimage.ps1

RUN \Run\buildimage.ps1

LABEL legal="$legal" \
      created="$created" \
      nav="$nav" \
      cu="$cu" \
      country="$country" \
      version="$version"
