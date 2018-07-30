#!/bin/sh

####
# Plugin Test Cases
####

log_prefix="[Plugin Test]"

# Start a LizardFS cluster for the plugin to connect to

# Set the LizardFS master port
echo "MASTER_PORT=9421" > .env

echo "$log_prefix Starting up local LizardFS cluster"
docker-compose down -v
docker-compose up -d

echo "$log_prefix Creating volume directory on LizardFS filesystem"
docker-compose exec client mkdir -p /mnt/mfs/docker/volumes

# Configure and enable plugin

echo "$log_prefix Configurin plugin to connect to 127.0.0.1:9421"
docker plugin disable lizardfs 2> /dev/null
docker plugin set lizardfs HOST=127.0.0.1 && \
docker plugin set lizardfs PORT=9421 && \
docker plugin set lizardfs REMOTE_PATH=/docker/volumes && \
docker plugin set lizardfs ROOT_VOLUME_NAME="" && \
docker plugin set lizardfs MOUNT_OPTIONS="" && \
docker plugin set lizardfs CONNECT_TIMEOUT=10000 && \
docker plugin set lizardfs LOG_LEVEL=info && \
docker plugin enable lizardfs

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Create volumes and make sure that they exist

echo "$log_prefix Create volume: lizardfs-volume-1" && \
docker volume create --driver lizardfs lizardfs-volume-1 && \
\
echo "$log_prefix Make sure lizardfs-volume-1 exists in volume list" && \
docker volume ls | grep "lizardfs.*lizardfs-volume-1" && \
\
echo "$log_prefix Make sure lizardfs-volume-1 exists on LizardFS filesystem" && \
docker-compose exec client ls /mnt/mfs/docker/volumes | grep lizardfs-volume-1 && \
\
echo "$log_prefix Create a second volume: lizardfs-volume-2" && \
docker volume create --driver lizardfs lizardfs-volume-2 && \
\
echo "$log_prefix Make sure lizardfs-volume-2 exists" && \
docker volume ls | grep "lizardfs.*lizardfs-volume-2" && \
\
echo "$log_prefix Make sure lizardfs-volume-1 still exists" && \
docker volume ls | grep "lizardfs.*lizardfs-volume-1"

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Store data in a volume and make sure that the data is persisted

echo "$log_prefix Create test data on lizardfs-volume-1" && \
docker run -it --rm -v lizardfs-volume-1:/data --entrypoint=bash \
kadimasolutions/lizardfs -c 'echo "Hello World" > /data/test-data.txt' && \
\
echo "$log_prefix Make sure data exists in volume" && \
docker run -it --rm -v lizardfs-volume-1:/data --entrypoint=cat \
kadimasolutions/lizardfs /data/test-data.txt | grep "Hello World" && \
\
echo "$log_prefix Make sure data exists on LizardFS filesystem" && \
docker-compose exec client cat \
/mnt/mfs/docker/volumes/lizardfs-volume-1/test-data.txt | grep "Hello World"

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Mount a volume into multiple containers, then remove the containers,
# and remount

echo "$log_prefix Mount lizardfs-volume-1 into container1 and container2" && \
docker run -d --name container1 -it --rm -v lizardfs-volume-1:/data --entrypoint=bash \
kadimasolutions/lizardfs && \
\
docker run -d --name container2 -it --rm -v lizardfs-volume-1:/data --entrypoint=bash \
kadimasolutions/lizardfs && \
\
echo "$log_prefix Make sure data exists in container1" && \
docker exec -it container1 cat /data/test-data.txt | grep "Hello World" && \
\
echo "$log_prefix Make sure data exists in container2" && \
docker exec -it container2 cat /data/test-data.txt | grep "Hello World" && \
\
echo "$log_prefix Remove container1" && \
docker stop container1 && \
\
echo "$log_prefix Make sure data still exists in container2" && \
docker exec -it container2 cat /data/test-data.txt | grep "Hello World" && \
\
echo "$log_prefix Remove container2" && \
docker stop container2 && \
\
echo "$log_prefix Make sure lizardfs-volume-1 can still be mounted into a new container" && \
docker run -it --rm -v lizardfs-volume-1:/data --entrypoint=cat \
kadimasolutions/lizardfs /data/test-data.txt | grep "Hello World"

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Create a volume with a specified replication goal and check that it is set
# when the volume is created

echo "$log_prefix Create lizardfs-volume-3 with a replication goal of '3'" && \
docker volume create --driver lizardfs lizardfs-volume-3 -o ReplicationGoal=3 && \
\
echo "$log_prefix Make sure that the volume has a replication goal of '3'" && \
docker-compose exec \
client lizardfs getgoal /mnt/mfs/docker/volumes/lizardfs-volume-3 | \
grep ".*lizardfs-volume-3: 3"

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Bring down the cluster

echo "$log_prefix Bringing down LizardFS cluster" && \
echo "$log_prefix Remove volumes" && \
docker volume rm lizardfs-volume-1 && \
docker volume rm lizardfs-volume-2 && \
docker volume rm lizardfs-volume-3 && \
echo "$log_prefix Remove LizardFS cluster" && \
docker-compose down -v && \
echo "$log_prefix Disable plugin" && \
docker plugin disable -f lizardfs

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Test connecting to cluster on a different port, storage directory, with mount
# options, and with the root volume name set

echo "MASTER_PORT=9900" > .env

echo "$log_prefix Creating cluster with master port 9900" && \
docker-compose up -d && \
\
echo "$log_prefix Creating storage directory, /alternate-volumes, on LizardFS filesystem" && \
docker-compose exec client mkdir -p /mnt/mfs/alternate-volumes && \
\
echo "$log_prefix Enabling plugin with PORT=9900, REMOTE_PATH=/alternate-volumes," && \
echo "$log_prefix MOUNT_OPTIONS='-o allow_other', and ROOT_VOLUME_NAME=lizardfs" && \
docker plugin set lizardfs PORT=9900 REMOTE_PATH=/alternate-volumes \
MOUNT_OPTIONS='-o allow_other' ROOT_VOLUME_NAME=lizardfs && \
docker plugin enable lizardfs && \
\
echo "$log_prefix Create volume 'volume-on-different-port' to test connection" && \
docker volume create --driver lizardfs volume-on-different-port && \
\
echo "$log_prefix Make sure volume-on-different-port exists in volume list" && \
docker volume ls | grep "lizardfs.*volume-on-different-port" && \
\
echo "$log_prefix Make sure that the mount options are getting set" && \
ps -ef | grep "allow_other" | grep -v "grep" && \
\
echo "$log_prefix Remove volume: volume-on-different-port" && \
docker volume rm volume-on-different-port

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Run tests for the Root Volume

echo "$log_prefix Create volumes: liz-1, liz-2" && \
docker volume create --driver lizardfs liz-1 && \
docker volume create --driver lizardfs liz-2 && \
\
echo "$log_prefix Add test-files liz-1, liz-2" && \
docker run -it --rm -v liz-1:/data --entrypoint=touch \
kadimasolutions/lizardfs /data/liz-1.txt && \
docker run -it --rm -v liz-2:/data --entrypoint=touch \
kadimasolutions/lizardfs /data/liz-2.txt && \
\
echo "$log_prefix Mount Root Volume and make sure liz-1, liz-2, and their files are in it" && \
docker run -it --rm -v lizardfs:/lizardfs --entrypoint=ls \
kadimasolutions/lizardfs /lizardfs/liz-1 | grep "liz-1.txt" && \
docker run -it --rm -v lizardfs:/lizardfs --entrypoint=ls \
kadimasolutions/lizardfs /lizardfs/liz-2 | grep "liz-2.txt" && \
\
echo "$log_prefix Create a new directory, liz-3, in the Root Volume" && \
docker run -it --rm -v lizardfs:/lizardfs --entrypoint=mkdir \
kadimasolutions/lizardfs /lizardfs/liz-3 && \
\
echo "$log_prefix Make sure the new directory registers in the volume list" && \
docker volume ls | grep "lizardfs.*liz-3" && \
\
echo "$log_prefix Create a volume with the same name as the Root Volume" && \
docker run -it --rm -v lizardfs:/lizardfs --entrypoint=mkdir \
kadimasolutions/lizardfs /lizardfs/lizardfs && \
\
echo "$log_prefix Make sure that the Root Volume takes precedence when mounting" && \
docker run -it --rm -v lizardfs:/lizardfs --entrypoint=ls \
kadimasolutions/lizardfs /lizardfs/liz-1 | grep "liz-1.txt"

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Make sure you can't delete the Root Volume" &&
docker volume rm lizardfs

if [ $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Make sure all volumes still exist after attempting to delete the Root Volume"
docker volume ls | grep "lizardfs.*liz-1" && \
docker volume ls | grep "lizardfs.*liz-2" && \
docker volume ls | grep "lizardfs.*liz-3" && \
\
echo "$log_prefix Delete the volumes" && \
docker volume rm liz-1 && \
docker volume rm liz-2 && \
docker volume rm liz-3

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Test setting the log level

plugin_id=$(docker plugin ls | grep lizardfs | awk '{print $1}')

echo "$log_prefix Test a 'docker volume ls'" && \
docker volume ls
if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Make sure plugin is not logging DEBUG messages"
cat /var/log/docker.log | grep $plugin_id | tail -n 1 | grep DEBUG
if [ $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Set log level to 'DEBUG'" && \
docker plugin disable -f lizardfs && \
docker plugin set lizardfs LOG_LEVEL=DEBUG && \
docker plugin enable lizardfs && \
\
echo "$log_prefix Test a 'docker volume ls'" && \
docker volume ls && \
\
echo "$log_prefix Make Sure that the plugin does log a DEBUG message" && \
cat /var/log/docker.log | grep $plugin_id | tail -n 1 | grep DEBUG

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Bring down the cluster

echo "$log_prefix Remove LizardFS cluster" && \
docker-compose down -v

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

# Test setting the CONNECT_TIMEOUT

echo "$log_prefix Setting the plugin HOST='not-a-cluster' CONNECT_TIMEOUT='3000'" && \
docker plugin disable lizardfs && \
docker plugin set lizardfs HOST=not-a-cluster && \
docker plugin set lizardfs CONNECT_TIMEOUT=3000 && \
docker plugin enable lizardfs

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Check timeout when connecting to non-existent cluster"
time -f %e -o /tmp/elapsed docker volume ls
elapsed=$(cat /tmp/elapsed | awk -F . '{print $1}')

if [ $elapsed -gt 4 -o $elapsed -lt 2 ]; then echo "TEST FAILED"; exit 1; fi

echo "$log_prefix Setting the plugin HOST='not-a-cluster' CONNECT_TIMEOUT='10000'" && \
docker plugin disable lizardfs && \
docker plugin set lizardfs HOST=not-a-cluster && \
docker plugin set lizardfs CONNECT_TIMEOUT=10000 && \
docker plugin enable lizardfs

if [ ! $? -eq 0 ]; then echo "TEST FAILED"; exit $?; fi

echo "$log_prefix Check timeout when connecting to non-existent cluster"
time -f %e -o /tmp/elapsed docker volume ls
elapsed=$(cat /tmp/elapsed | awk -F . '{print $1}')

if [ $elapsed -gt 11 -o $elapsed -lt 9 ]; then echo "TEST FAILED"; exit 1; fi

echo "$log_prefix ALL DONE. SUCCESS!"
