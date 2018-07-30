# LizardFS Docker Plugin

A Docker volume driver plugin for mounting a [LizardFS](https://lizardfs.com) filesystem. Allows you to transparently provide storage for your Docker containers using LizardFS. This plugin can be used in combination with our [LizardFS Docker Image](https://github.com/kadimasolutions/docker_lizardfs) to create a fully containerized, clustered storage solution for Docker Swarm. Documentation and development are still in progress. A guide for getting started with Swarm can be found in [Getting Started](getting-started.md). The Swarm usage will likely be changed soon in favor of combining the LizardFS services with the plugin.

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

## Development

Docker plugins are made up of a `config.json` file and `rootfs` directory. The `config.json` has all of the metadata and information about the plugin that Docker needs when installing and configuring the plugin. The `rootfs` is the root filesystem of the plugin container. Unfortunately the Docker CLI doesn't allow you to create Docker plugins using a Dockerfile so we use a Makefile to automate the process of creating the plugin `rootfs` from a Dockerfile.

### Building the Plugin

To build the plugin simply run `make rootfs` in the project directory.

    $ make rootfs

This will build the Dockerfile, export the new Docker image's rootfs, and copy the rootfs and the config.json file to the `plugin` directory. When it is done you should have a new plugin directory with a config.json file and a rootfs folder in it.

```
plugin/
  config.json
  rootfs/
```

After that is finished you can run `make create`.

    $ make create

This will install the Docker plugin from the `plugin` dirctory with the name `kadimasolutions/lizardfs-volume-plugin`.

Finally run `make enable` to start the plugin.

    $ make enable

 Here is a list of the `make` targets:

* **clean**: Remove the `plugin` directory
* **config**: Copy the `config.json` file to the `plugin` directory
* **rootfs**: Generate the plugin rootfs from the Dockerfile and put it in the `plugin` directory with the `config.json`
* **create**: Install the plugin from the `plugin` directory
* **enable**: Enable the plugin
* **disable**: Disable the plugin
* **push**: Run the `clean`, `rootfs`, `create`, and `enable` targets, and push the plugin to DockerHub

### Running the tests

The automated tests for the plugin are run using a Docker-in-Docker container that creates a Dockerized LizardFS cluster to test the plugin against. When you run the test container, it will install the plugin inside the Docker-in-Docker container and proceed to create a Dockerized LizardFS cluster in it as well. A shell script is run that manipulates the plugin and runs containers to ensure the plugin behaves as is expected.

Before you can run the tests, the test Docker image must first be built. This is done by running the `build-tests.sh` script.

    $ ./build-tests.sh

This will build a Docker image, `lizardfs-volume-plugin_test`, using the Dockerfile in the `test` directory. After the image has been built, you can use it to run the tests against the plugin. This is done with the `run-tests.sh` script.

    $ ./run-tests.sh

By default running `run-tests.sh` will install the plugin from the `plugin` directory before running the tests against it. This means that you must first build the plugin by running `make rootfs`, if you have not already done so. Alternatively, you can also run the tests against a version of the plugin from DockerHub by passing in the plugin tag as a parameter to the `run-tests.sh` script.

    $ ./run-tests.sh kadimasolutions/lizardfs-volume-plugin:latest

This will download the plugin from DockerHub and run the tests against that version of the plugin.

### Tips & Tricks

If you don't have a fast disk on your development machine, developing Docker plugins can be somewhat tricky, because it can take some time to build and install the plugin every time you need to make a change. Here are some tricks that you can use to help maximize your development time.

#### Patching the Plugin Rootfs

All of the plugin logic is in the `index.js` file. During development it can take a long time to rebuild the entire plugin every time you need to test a change to `index.js`. To get around this, it is possible to copy just that file into the installed plugin without having to reinstall the entire plugin.

When you install a Docker plugin, it is given a plugin ID. You can see the first 12 characters of the plugin ID by running `docker plugin ls`.

```
$ docker plugin ls
ID                  NAME                                            DESCRIPTION                         ENABLED
2f5b68535b92        kadimasolutions/lizardfs-volume-plugin:latest   LizardFS volume plugin for Docker   false
```

Using that ID you can find where the plugin's rootfs was installed. By default, it should be located in `/var/lib/docker/plugins/[pluginID]/rootfs`. For our particular plugin, the file that we need to replace is the `/project/index.js` file in the plugin's rootfs. By replacing that file with an updated version and restarting ( disabling and re-enabling ) the plugin, you can update the plugin without having to re-install it.

#### Exec-ing Into the Plugin Container

It may be useful during development to exec into the plugin container while it is running. You can find out how in the [Docker Documentation](https://docs.docker.com/engine/extend/#debugging-plugins).

#### Test Case Development

Writing new automated test cases for the plugin can also be difficult because of the time required for the test container to start. When writing new test cases for the plugin, it may be useful to start the container and interactively run the tests. If you make a mistake that causes a test to fail, even though the plugin *is* working, you can still edit and re-run the tests without having to restart the test container completely.

Once you have built the test image using the `build-tests.sh` script, you need to run the test container as a daemon that you can exec into. We override the entrypoint of the container so that it won't run the test script as soon as it starts. We want it just to sit there and wait for us to run commands in it.

    $ docker run -it --rm -d --name lizardfs-test --privileged \
    -v $(pwd)/plugin:/plugin \
    -v $(pwd)/test/test-run.sh:/test-run.sh \
    --entrypoint=sh \
    lizardfs-volume-plugin_test

> **Note:** We also mount our `test-run.sh` script into the container so that updates to the script are reflected immediately in the container.

After the container is running we can shell into it and run the script that starts up Docker.

    $ docker exec -it lizardfs-test sh
    /project # /test-environment.sh

This will start Docker, load the LizardFS image used for creating the test LizardFS environment, and install the plugin from the plugin directory. Once this is done you can run the tests.

    /project # sh /test-run.sh

This will run through all of the tests. If the tests fail, you can still edit and re-run the `test-run.sh` script without having to re-install the plugin.

When you are done writing your test cases, you can `exit` the shell and `docker stop lizardfs-test`. The container will be automatically removed after it stops. You should make sure that your tests still run correctly in a completely fresh environment by rebuilding and re-running the tests using the `build-tests.sh` and `run-tests.sh` scripts.
