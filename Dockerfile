FROM node:8-slim

####
# Install LizardFS client
####

# Install LizardFS Key
RUN wget -O - http://packages.lizardfs.com/lizardfs.key | apt-key add -

# Add apt repositories
RUN echo "deb http://packages.lizardfs.com/debian/jessie jessie main" > /etc/apt/sources.list.d/lizardfs.list && \
    echo "deb-src http://packages.lizardfs.com/debian/jessie  jessie main" >> /etc/apt/sources.list.d/lizardfs.list

# Install LizardFS packages
RUN apt-get update && \
    apt-get install -y lizardfs-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

####
# Install Docker volume driver API server
####

# Create directories for mounts
RUN mkdir -p /mnt/lizardfs
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
    ALIAS=lizardfs \
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
