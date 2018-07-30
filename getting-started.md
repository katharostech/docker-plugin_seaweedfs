Hello Everybody, I have recently developed a Docker plugin that allows you to create LizardFS Docker volumes! There are two different versions of the plugin: a Docker managed plugin that works well for individual Docker instances, and a version that can be deployed as a stack on Docker Swarm to create a self-contained storage solution for a Docker cluster.

The Docker plugin has been developed by me and my team at @kadimasolutions to create a distributed storage solution that can be deployed on Docker Swarm and provide shared volumes for the containers in the Docker Swarm cluster. As far as I have found it is **the only** solution that does so.

We will soon mirror the source code for the plugin to GitHub. In the meantime, you can test out the plugin using the Docker images that are on DockerHub. The plugin can be considered in beta and is, as far as I can tell, completely functional, but there may still be bugs or nuances that we have not yet found. Feedback is appreciated. :smiley: Updates to the image on DockerHub may be made without notice, I will try to mention any changes that I make here.

In addition, I will soon be attempting to get the Swarm deployment setup with the very latest highly available LizardFS master from the LizardFS 3.13 release candidate ( thanks to the folks at @lizardfs for getting that to me early ) so that the deployed LizardFS cluster will have automatic failover.

Here are detailed instructions for getting started with both versions of the plugin. If you need any help just comment on this thread and I will try to do what I can when I have the time.

# Docker Managed plugin

The Docker managed plugin can be installed very easily on any Docker host and is great for connecting your Docker containers to an existing LizardFS cluster.

> **Note:** If you don't have a LizardFS cluster, yet you may want to consider using the Swarm deployment instead. You can use the Docker Swarm deployment to create a LizardFS cluster out of your Docker hosts that will supply your Docker containers with shared LizardFS volumes that are distributed across you Docker cluster.

## Usage

### Prerequisites

Before you can use the plugin you must have:

* A running LizardFS cluster that your Docker host can access.
* A directory on the LizardFS filesystem that can be used by the plugin to store Docker volumes. This can be any normal directory. By default the plugin will use `/docker/volumes`, but this can be changed ( see [REMOTE_PATH](#remote-path) ).

Once these conditions are met you are ready to install the plugin.

### Installation

The plugin is simple use and can be installed as a Docker container without having to install any other system dependencies.

    $ docker plugin install --alias lizardfs kadimasolutions/lizardfs-volume-plugin HOST=mfsmaster PORT=9421

Docker will prompt asking if you want to grant the permissions required to run the plugin. Select yes and the plugin will download and install.

> **Note:** We set the plugin alias to `lizardfs`. This is completely optional, but it allows us to refer to the plugin with a much shorter name. Throughout this readme, when reference is made to the `lizardfs` driver, it is referring to this alias.

That's it! You can now see your newly installed Docker plugin by running `docker plugin ls`.

    $ docker plugin ls
    ID                  NAME                 DESCRIPTION                         ENABLED
    4a08a23cf2eb        lizardfs:latest      LizardFS volume plugin for Docker   true

You should now be able to create a Docker volume using our new `lizardfs` driver.

    $ docker volume create --driver lizardfs lizard-vol
    lizard-vol

You can see it by running `docker volume ls`.

    $ docker volume ls
    DRIVER               VOLUME NAME
    lizardfs:latest      lizard-vol

Now that you have created the volume you can mount it into a container using its name. Lets mount it into an alpine container and put some data in it.

```sh
$ docker run -it --rm -v lizard-vol:/data alpine sh
/ $ cd /data # Switch to our volume mountpoint
/data $ cp -R /etc . # Copy the whole container /etc directory to it
/data $ ls # See that the copy was successful
etc
/data $ exit # Exit ( the container will be removed because of the --rm )
```

We should now have a copy of the alpine container's whole `/etc` directory on our `lizard-vol` volume. You can verify this by checking the `/docker/volumes/lizard-vol/` directory on your LizardFS installation. You should see the `etc` folder with all of its files and folders in it. Congratulations! You have successfully mounted your LizardFS filesytem into a docker container and stored data in it!

If you run another container, you can mount the same volume into it and that container will also see the data. Your data will stick around as long as that volume exists. When you are done with it, you can remove the volume by running `docker volume rm lizard-vol`.

### Features

#### Shared Mounts

Any number of containers on any number of hosts can mount the same volume at the same time. The only requirement is that each Docker host have the LizardFS plugin installed on it.

#### Transparent Data Storage ( No Hidden Metadata )

Each LizardFS Docker volume maps 1-to-1 to a directory on the LizardFS filesystem. All directories in the [REMOTE_PATH](#remote-path) on the LizardFS filesystem will be exposed as a Docker volume regardless of whether or not the directory was created by running `docker volume create`. There is no special metadata or any other extra information used by the plugin to keep track of what volumes exist. If there is a directory there, it is a Docker volume and it can be mounted ( and removed ) by the LizardFS plugin. This makes it easy to understand and allows you to manage your Docker volumes directly on the filesystem, if necessary, for things like backup and restore.

#### LizardFS Global Trash Bin

Using LizardFS for your Docker volumes means that you now get the benefit of LizardFS's global trash bin. Removed files and volumes can be restored using LizardFS's [trash bin](https://docs.lizardfs.com/adminguide/advanced_configuration.html?highlight=trash#mounting-the-meta-data) mechanism. Note that the plugin itself has nothing to do with this; it is a native feature of LizardFS.

#### Multiple LizardFS Clusters

It is also possible, if you have multiple LizardFS clusters, to install the plugin multiple times with different settings for the different clusters. For example, if you have two LizardFS clusters, one at `mfsmaster1` and another at `mfsmaster2`, you can install the plugin two times, with different aliases, to allow you to create volumes on both clusters.

    $ docker plugin install --alias lizardfs1 --grant-all-permissions kadimasolutions/lizardfs-volume-plugin HOST=mfsmaster1 PORT=9421
    $ docker plugin install --alias lizardfs2 --grant-all-permissions kadimasolutions/lizardfs-volume-plugin HOST=mfsmaster2 PORT=9421

This gives you the ability to create volumes for both clusters by specifying either `lizardfs1` or `lizardfs2` as the volume driver when creating a volume.

#### Root Mount Option

The plugin has the ability to provide a volume that contains *all* of the LizardFS Docker volumes in it. This is called the Root Volume and is identical to mounting the configured `REMOTE_PATH` on your LizardFS filesystem into your container. This volume does not exist by default. The Root Volume is enabled by setting the `ROOT_VOLUME_NAME` to the name that you want the volume to have. You should pick a name that does not conflict with any other volume. If there is a volume with the same name as the Root Volume, the Root Volume will take precedence over the other volume.

There are a few different uses for the Root Volume. Kadima Solutions designed the Root Volume feature to accommodate for containerized backup solutions. By mounting the Root Volume into a container that manages your Backups, you can backup *all* of your LizardFS Docker volumes without having to manually add a mount to the container every time you create a new volume that needs to be backed up.

The Root Volume also give you the ability to have containers create and remove LizardFS volumes without having to mount the Docker socket and make Docker API calls. Volumes can be added, removed, and otherwise manipulated simply by mounting the Root Volume and making the desired changes.

### Known Issues

#### Hangs on Unresponsive LizardFS Master

In most cases, when the plugin cannot connect to the LizardFS cluster, the plugin will timeout quickly and simply fail to create mounts or listings of volumes. However, when the plugin *has* been able to open a connection with the LizardFS master, and the LizardFS master subsequently fails to respond, a volume list operation will cause the plugin to hang for a period of time. This will cause any Docker operations that request the volume list to freeze while the plugin attempts to connect to the cluster. To fix the issue, the connectivity to the LizardFS master must be restored, otherwise the plugin should be disabled to prevent stalling the Docker daemon.

## Configuration

### Plugin Configuration

You can configure the plugin through plugin variables. You may set these variables at installation time by putting `VARIABLE_NAME=value` after the plugin name, or you can set them after the plugin has been installed using `docker plugin set kadimasolutions/lizardfs-volume-plugin VARIABLE_NAME=value`.

> **Note:** When configuring the plugin after installation, the plugin must first be disabled before you can set variables. There is no danger of accidentally setting variables while the plugin is enabled, though. Docker will simply tell you that it is not possible.

#### HOST

The hostname/ip address that will be used when connecting to the LizardFS master.

> **Note:** The plugin runs in `host` networking mode. This means that even though it is in a container, it shares its network configuration with the host and should resolve all network addresses as the host system would.

**Default:** `mfsmaster`

#### PORT

The port on which to connect to the LizardFS master.

**Default:** `9421`

#### MOUNT_OPTIONS

Options passed to the `mfsmount` command when mounting LizardFS volumes. More information can be found in the [LizardFS documentation](https://docs.lizardfs.com/man/mfsmount.1.html).

**Default:** empty string

#### REMOTE_PATH

The path on the LizardFS filesystem that Docker volumes will be stored in. This path will be mounted for volume storage by the plugin and must exist on the LizardFS filesystem. The plugin fail to connect to the master server if the path does not exist.

**Default:** `/docker/volumes`

#### ROOT_VOLUME_NAME

The name of the Root Volume. If specified, a special volume will be created of the given name will be created that will contain all of the LizardFS volumes. It is equivalent to mounting the `REMOTE_PATH` on the LizardFS filesystem. See [Root Mount Option](#root-mount-option).

**Default:** empty string

#### CONNECT_TIMEOUT

The timeout for LizardFS mount commands. If a mount takes longer than the `CONNECT_TIMEOUT` in milliseconds, it will be terminated and the volume will not be mounted. This is to keep Docker operations from hanging in the event of an unresponsive master.

**Default:** `10000`

#### LOG_LEVEL

Plugin logging level. Set to `DEBUG` to get more verbose log messages. Logs from Docker plugins can be found in the Docker log and will be suffixed with the plugin ID.

**Default:** `INFO`

### Volume Options

Volume options are options that can be passed to Docker when creating a Docker volume. Volume options are set per volume, therefore setting an option for one volume does not set that option for any other volume.

Volume options can be passed in on the command line by
adding `-o OptionName=value` after the volume name. For example:

    $ docker volume create -d lizardfs my-volume -o ReplicationGoal=3

#### ReplicationGoal

The replication goal option can be used to set the LizardFS replication goal on a newly created volume. The goal can be any valid goal name or number that exists on the LizardFS master. See the LizardFS [documentation](https://docs.lizardfs.com/adminguide/replication.html) for more information.

Note that even after a volume has been created and a goal has been set, it is still possible to manually change the goal of the volume directory on the LizardFS filesystem manually. For example, assuming you have mounted the LizardFS filesystem manually ( not using a docker volume ):

    lizardfs setgoal goal_name /mnt/mfs/docker/volumes/volume_name

Also, if you want to set a default goal for all of your Docker volumes, you can manually set the goal of the directory containing your docker volumes on the LizardFS filesystem ( `/docker/volumes` by default, see [REMOTE_PATH](#remote-path) ).

**Default:** empty string

# Swarm Deployment

Docker Swarm is where the LizardFS plugin shows its full potential. You can deploy an entire LizardFS cluster *and* the Docker volume plugin as a single stack on you Docker Swarm. This lets you create a shared storage cluster out of any Docker Swarm. There are a few steps to prepare your hosts before launching the stack.

## Usage

### Setup Master

One node in your Swarm cluster needs to have the label `lizardfs.master-personality=master`. This is the node that the LizardFS master will be deployed on.

The master server is also expected to have a directory /lizardfs/mfsmaster on the host that will be used to store the master data. In production this should be the mountpoint for an XFS or ZFS filesystem.
Setup Chunkservers

Every node in the Swarm cluster gets a Chunkserver deployed to it. All servers are expected to have a `/lizardfs/chunkserver` directory that will be used for storing chunks. Like the master storage directory, `/lizardfs/chunkserver` should be formatted XFS or ZFS for production installations.

### ( Optional ) Setup Shadow Masters

You can optionally add the lizardfs.master-personality=shadow label to any nodes in the cluster that you want to run shadow masters on. Shadow master servers should have a /lizardfs/mfsmaster-shadow directory that is mounted to an XFS or ZFS filesystem for storage.
Deploy The LizardFS Stack

> Note: Before you deploy the stack you should make sure that you have disabled the Docker managed version of the LizardFS plugin if it is installed.

After you have provided for the storage for your LizardFS cluster, you can deploy the LizardFS stack to your Swarm cluster by downloading the attached lizardfs.yml and using docker stack deploy -c lizardfs.yml lizardfs. The particular yaml I gave you requires that the name of the stack be lizardfs.

### Deploy the Stack

After you have setup the storage directories for you Swarm cluster you deploy the stack with the following yaml.

    $ docker stack deploy -c docker-stack.yml lizardfs

> **Note:** The stack **must** be named `lizardfs` for this yaml. It is because the `docker-run-d` container has the network name `lizardfs_lizardfs` hard-codded into the yaml. Reading the "Swarm Service Privileges Workaround" explanation below will help explain the `docker-run-d` container.

**docker-stack.yml**
```yaml
version: '3.6'
services:
  mfsmaster:
    image: kadimasolutions/lizardfs:latest
    command: master
    environment:
      MFSMASTER_AUTO_RECOVERY: 1
    networks:
      - lizardfs
    volumes:
      - /lizardfs/mfsmaster:/var/lib/mfs
    deploy:
      mode: global
      placement:
        constraints:
          - node.labels.lizardfs.master-personality==master
  mfsmaster-shadow:
    image: kadimasolutions/lizardfs:latest
    command: master
    networks:
      - lizardfs
    environment:
      MFSMASTER_PERSONALITY: shadow
    volumes:
      - /lizardfs/mfsmaster-shadow:/var/lib/mfs
    deploy:
      mode: global
      placement:
        constraints:
          - node.labels.lizardfs.master-personality==shadow
  chunkserver:
    image: kadimasolutions/lizardfs:latest
    command: chunkserver
    networks:
      - lizardfs
    environment:
      # This lets you run the chunkserver with less available disk space
      MFSCHUNKSERVER_HDD_LEAVE_SPACE_DEFAULT: 400Mi # 4Gi is the default
      MFSHDD_1: /mnt/mfshdd
    volumes:
      - /lizardfs/chunkserver:/mnt/mfshdd
    deploy:
      mode: global
  cgiserver:
    image: kadimasolutions/lizardfs:latest
    command: cgiserver
    networks:
      - lizardfs
    restart: on-failure
    ports:
      - 8080:80
    deploy:
      replicas: 0
  docker-plugin:
    image: kadimasolutions/docker-run-d:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - "--restart=always -v /var/lib/docker/plugins/lizardfs/propagated-mount:/mnt/docker-volumes/:rshared -v /run/docker/plugins/lizardfs:/run/docker/plugins/ --net lizardfs_lizardfs --cap-add SYS_ADMIN --device=/dev/fuse:/dev/fuse --security-opt=apparmor:unconfined -e ROOT_VOLUME_NAME=lizardfs -e LOG_LEVEL=debug -e REMOTE_PATH=/docker/volumes -e LOCAL_PATH=/var/lib/docker/plugins/lizardfs/propagated-mount -e MOUNT_OPTIONS='-o big_writes -o cacheexpirationtime=500 -o readaheadmaxwindowsize=1024' kadimasolutions/lizardfs-volume-driver"
    environment:
      CONTAINER_NAME: lizardfs-plugin
    deploy:
      mode: global
  lizardfs-client:
    image: kadimasolutions/docker-run-d:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command:
      - "--restart=always --net lizardfs_lizardfs --cap-add SYS_ADMIN --device=/dev/fuse:/dev/fuse --security-opt=apparmor:unconfined kadimasolutions/lizardfs client"
    environment:
      CONTAINER_NAME: lizardfs-client
    deploy:
      mode: global

networks:
  lizardfs:
    attachable: true
```

This will deploy the Docker plugin, the LizardFS chunkserver, and a LizardFS client container on *every* host in your cluster. If you have different goals, you may want to update the scheduling rules to match your particular use case.

The stack uses @kadimasolutions's LizardFS Docker image to create the LizardFS cluster. You can modify the environment variables for the mfsmaster, mfsmaster-shadow, and chunkserver containers to completely configure your LizardFS cluster. Documetnation for the `kadimasolutions/lizardfs` docker image can be found in the [git repo](https://github.com/kadimasolutions/docker_lizardfs).

### Things You Should Know

Here are some things that you should know about the setup.

#### Different Container Image

The new container for deploying the plugin is actually the same software as the Docker managed plugin, but it is under a different repo on DockerHub. The plugin that you install with docker plugin install is under the kadimasolutions/lizardfs-volume-plugin repository. The plugin that you run as a standard Docker container on Swarm is under the kadimasolutions/lizardfs-volume-driver repository ( these may or may not be the final names for either ). The only difference between the two are how they are installed, otherwise they are running the same code.

#### Swarm Service Privileges Workaround

There is a limitation imposed by the Docker daemon on Swarm services that prevents them from running with admin privileges on the host. This is an issue for the LizardFS plugin container because it needs to have the SYS_ADMIN capability along with the FUSE device. In order to work around this I created a very simple container ( kadimasolutions/docker-run-d ) that uses the Docker CLI to run a container that does have privileges. This container can be deployed as a Swarm service to allow you to run privileged swarm containers. This is how the docker-plugin and lizardfs-client services are deployed in the attached yaml.

#### lizardfs-client Convenience Container

As a convenience, the stack will deploy a container named lizardfs-client on every host in your Swarm. This container mounts the root of the LizardFS filesystem to /mnt/mfs and provides the LizardFS CLI tools to allow you to manage your LizardFS filesystem. To access the tools you exec into the lizardfs-client container on any host in your cluster. For example:

    $ docker exec -it lizardfs-client bash
    root@containerid $ lizardfs setgoal 3 /mnt/mfs/docker/volumes
    root@containerid $ exit

This removes the need to install any LizardFS tools on your hosts.

### Known Issues

#### Docker Restart Issue

> **Note:** This is only a concern when using the Swarm deployment. It is not a problem when using the Docker managed version of the plguin.

When the Docker daemon is started it checks to make sure that all of your LizardFS volumes exist and it tries to connect to the LizardFS Docker plugin. Because I am running the plugin in a Docker container, the Docker daemon cannot connect to the plugin as the daemon is still starting up and the plugin container has not been started yet. Unfortunately, Docker will spend about 15 seconds timing out for each lizardfs volume before it finishes starting up. This can push your Docker daemon startup time up by several minutes if you have a lot of LizardFS volumes. After it finishes timing out for each volume, the Docker daemon starts up and everything works as you would expect.

This doesn’t cause any critical issues it just takes longer to start Docker because of all of the timeouts. Another option that I’ve speculated is to run two Docker daemons on each host in the cluster and create a dedicated Swarm cluster just for LizardFS. This would be more of a specialized setup, but I think it would still work. In the end I think that the method of deployment will depend on the individual user’s needs. Eventually I may try to test and document more deployment methods
