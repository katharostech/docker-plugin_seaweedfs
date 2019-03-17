FROM node:10-alpine

####
# Install SeaweedFS Client
####

ARG SEAWEEDFS_VERSION=1.25
ENV SEAWEEDFS_VERSION=$SEAWEEDFS_VERSION

RUN apk update && \
    apk add fuse3 && \
    apk add --no-cache --virtual build-dependencies --update wget curl ca-certificates && \
    wget -qO /tmp/linux_amd64.tar.gz https://github.com/chrislusf/seaweedfs/releases/download/${SEAWEEDFS_VERSION}/linux_amd64.tar.gz && \
    tar -C /usr/bin/ -xzvf /tmp/linux_amd64.tar.gz && \
    apk del build-dependencies && \
    rm -rf /tmp/*

####
# Install Docker volume driver API server
####

# Create directories for mounts
RUN mkdir -p /mnt/seaweedfs
RUN mkdir -p /mnt/docker-volumes

# Copy in package.json
COPY package.json package-lock.json /project/

# Switch to the project directory
WORKDIR /project

# Install project dependencies
RUN npm install

# Set Configuration Defaults
ENV HOST=mfsmaster \
    PORT=9421 \
    ALIAS=seaweedfs \
    ROOT_VOLUME_NAME="" \
    MOUNT_OPTIONS="" \
    REMOTE_PATH=/docker/volumes \
    LOCAL_PATH="" \
    CONNECT_TIMEOUT=10000 \
    LOG_LEVEL=info

# Copy in source code
COPY index.js /project

# Set the Docker entrypoint
ENTRYPOINT ["node", "index.js"]
