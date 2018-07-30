#!/usr/bin/env bash
pushd test
docker build \
--build-arg http_proxy="$http_proxy" \
--build-arg https_proxy="$https_proxy" \
-t lizardfs-volume-plugin_test .
popd
