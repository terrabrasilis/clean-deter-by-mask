#!/bin/bash
docker run --rm --workdir="/data" \
-v /postgres/docker/git-clone-projects/clean-deter-by-mask:/data \
terrabrasilis/deter-clean-postgis:13-3.1-alpine ./start_process.sh