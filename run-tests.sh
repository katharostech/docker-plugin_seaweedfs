#!/usr/bin/env bash
docker run -it --rm --privileged \
-e http_proxy="$http_proxy" \
-e https_proxy="$https_proxy" \
-e no_proxy="$no_proxy" \
-v $(pwd)/plugin:/plugin \
lizardfs-volume-plugin_test $@
