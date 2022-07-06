FROM postgis/postgis:13-3.1-alpine

LABEL "br.inpe.dpi"="INPE/DPI-TerraBrasilis"
LABEL br.inpe.dpi.terrabrasilis="tools"
LABEL author="Andre Carvalho"
LABEL author.email="andre.carvalho@inpe.br"
LABEL description="To clean DETER by PRODES"

RUN apk update \
  && apk add --no-cache --update \
    libintl \
    && rm -rf /var/cache/apk/*