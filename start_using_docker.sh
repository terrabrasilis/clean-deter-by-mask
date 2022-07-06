#!/bin/bash
docker run --rm --workdir="/data" \
-v /home/andre/Dados/homeAndre/Projects/workspace-terrabrasilis2.0/clean-deter-by-mask:/data \
terrabrasilis/deter-clean-postgis:13-3.1-alpine ./start_process.sh