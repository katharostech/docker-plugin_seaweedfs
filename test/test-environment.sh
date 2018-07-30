#!/bin/sh

image_tag=$1

log_prefix="[Plugin Environment]"

echo "$log_prefix Starting Docker"
dockerd-entrypoint.sh 2> /var/log/docker.log &
echo $! > /run/dockerd-entrypoint.pid

# Wait for Docker to startup
while ! docker ps > /var/log/docker.log; do
  sleep 1
done
echo "$log_prefix Docker finished startup"

echo "$log_prefix Loading baked LizardFS image"
tar -cC '/images/lizardfs' . | docker load

# Install plugin
if [ -z "$image_tag" ]; then
  echo "$log_prefix Installing plugin from local dir"
  docker plugin create lizardfs /plugin
else
  echo "$log_prefix Installing Plugin from DockerHub: $image_tag"
  docker plugin install --alias lizardfs --grant-all-permissions --disable $image_tag
fi
