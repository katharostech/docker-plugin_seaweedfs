FROM docker:stable-dind

# Install dependencies
RUN apk add --no-cache bash curl jq python3 wget

# Install Docker compose
RUN pip3 install docker-compose

# Create our working directory
RUN mkdir /project

# Switch to our working directory
WORKDIR /project

# Pull the LizardFS image used for creating the test environment
RUN wget https://raw.githubusercontent.com/moby/moby/master/contrib/download-frozen-image-v2.sh -O /download-image.sh
RUN chmod 744 /download-image.sh
RUN mkdir -p /images/lizardfs
RUN /download-image.sh /images/lizardfs kadimasolutions/lizardfs:latest

# Copy in the docker compose file that we will use to create test LizardFS
# clusters
COPY ./docker-compose.yml /project/

# Copy in the test scripts
COPY ./test-environment.sh /test-environment.sh
RUN chmod 744 /test-environment.sh
COPY ./test-run.sh /test-run.sh
RUN chmod 744 /test-run.sh

# Copy in our entrypoint script
COPY ./docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 744 /docker-entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
