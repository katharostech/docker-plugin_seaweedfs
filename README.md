# SeaweedFS Docker Plugin

> **Note:** This plugin was forked from a [LizardFS Docker Plugin](https://github.com/kadimasolutions/docker-plugin_lizardfs) so there may still be references to LizardFS somewhere in here that I haven't found and replaced yet.

A Docker volume driver plugin for mounting a [SeaweedFS](https://github.com/chrislusf/seaweedfs) filesystem. Allows you to transparently provide storage for your Docker containers using SeaweedFS. This plugin can be used in combination with the [SeaweedFS Docker Image](https://github.com/chrislusf/seaweedfs/tree/master/docker) to create a fully containerized, clustered storage solution for Docker Swarm. Documentation and development are still in progress.

## Usage

### Prerequisites

Before you can use the plugin you must have:

* A running SeaweedFS cluster with a [Filer](https://github.com/chrislusf/seaweedfs/wiki/Directories-and-Files) that your Docker host can access.
* A directory on the SeaweedFS filesystem that can be used by the plugin to store Docker volumes. This can be any normal directory. By default the plugin will use `/docker/volumes`, but this can be changed to something else like the root directory, for example ( see [REMOTE_PATH](#remote-path) ).

Once these conditions are met you are ready to install the plugin.

### Installation

The plugin is simple use and can be installed as a Docker container without having to install any other system dependencies.

    $ docker plugin install --alias seaweedfs katharostech/seaweedfs-volume-plugin HOST=localhost:8888

Docker will prompt asking if you want to grant the permissions required to run the plugin. Select yes and the plugin will download and install.

> **Note:** We set the plugin alias to `seaweedfs`. This is completely optional, but it allows us to refer to the plugin with a much shorter name. Throughout this readme, when reference is made to the `seaweedfs` driver, it is referring to this alias.

That's it! You can now see your newly installed Docker plugin by running `docker plugin ls`.

    $ docker plugin ls
    ID                  NAME                 DESCRIPTION                         ENABLED
    4a08a23cf2eb        seaweedfs:latest     SeaweedFS volume plugin for Docker  true

You should now be able to create a Docker volume using our new `seaweedfs` driver.

    $ docker volume create --driver seaweedfs weed-vol
    weed-vol

You can see it by running `docker volume ls`.

    $ docker volume ls
    DRIVER               VOLUME NAME
    seaweedfs:latest      weed-vol

Now that you have created the volume you can mount it into a container using its name. Lets mount it into an alpine container and put some data in it.

```sh
$ docker run -it --rm -v weed-vol:/data alpine sh
/ $ cd /data # Switch to our volume mountpoint
/data $ cp -R /etc . # Copy the whole container /etc directory to it
/data $ ls # See that the copy was successful
etc
/data $ exit # Exit ( the container will be removed because of the --rm )
```

We should now have a copy of the alpine container's whole `/etc` directory on our `weed-vol` volume. You can verify this by checking the `/docker/volumes/weed-vol/` directory on your SeaweedFS installation. You should see the `etc` folder with all of its files and folders in it. Congratulations! You have successfully mounted your SeaweedFS filesytem into a docker container and stored data in it!

If you run another container, you can mount the same volume into it and that container will also see the data. Your data will stick around as long as that volume exists. When you are done with it, you can remove the volume by running `docker volume rm weed-vol`.

### Features

#### Shared Mounts

Any number of containers on any number of hosts can mount the same volume at the same time. The only requirement is that each Docker host have the SeaweedFS plugin installed on it.

#### Transparent Data Storage ( No Hidden Metadata )

Each SeaweedFS Docker volume maps 1-to-1 to a directory on the SeaweedFS filesystem. All directories in the [REMOTE_PATH](#remote-path) on the SeaweedFS filesystem will be exposed as a Docker volume regardless of whether or not the directory was created by running `docker volume create`. There is no special metadata or any other extra information used by the plugin to keep track of what volumes exist. If there is a directory there, it is a Docker volume and it can be mounted ( and removed ) by the SeaweedFS plugin. This makes it easy to understand and allows you to manage your Docker volumes directly on the filesystem, if necessary, for things like backup and restore.

#### Multiple SeaweedFS Clusters

It is also possible, if you have multiple SeaweedFS clusters, to install the plugin multiple times with different settings for the different clusters. For example, if you have two SeaweedFS clusters, one at `host1` and another at `host2`, you can install the plugin two times, with different aliases, to allow you to create volumes on both clusters.

    $ docker plugin install --alias seaweedfs1 --grant-all-permissions katharostech/seaweedfs-volume-plugin HOST=host1:8888
    $ docker plugin install --alias seaweedfs2 --grant-all-permissions kadimasolutions/seaweedfs-volume-plugin HOST=host2:8888

This gives you the ability to create volumes for both clusters by specifying either `seaweedfs1` or `seaweedfs2` as the volume driver when creating a volume.

#### Root Mount Option

The plugin has the ability to provide a volume that contains *all* of the SeaweedFS Docker volumes in it. This is called the Root Volume and is identical to mounting the configured `REMOTE_PATH` on your SeaweedFS filesystem into your container. This volume does not exist by default. The Root Volume is enabled by setting the `ROOT_VOLUME_NAME` to the name that you want the volume to have. You should pick a name that does not conflict with any other volume. If there is a volume with the same name as the Root Volume, the Root Volume will take precedence over the other volume.

There are a few different uses for the Root Volume. Katharos Technology designed the Root Volume feature to accommodate for containerized backup solutions. By mounting the Root Volume into a container that manages your Backups, you can backup *all* of your SeaweedFS Docker volumes without having to manually add a mount to the container every time you create a new volume that needs to be backed up.

The Root Volume also give you the ability to have containers create and remove SeaweedFS volumes without having to mount the Docker socket and make Docker API calls. Volumes can be added, removed, and otherwise manipulated simply by mounting the Root Volume and making the desired changes.

## Configuration

### Plugin Configuration

You can configure the plugin through plugin variables. You may set these variables at installation time by putting `VARIABLE_NAME=value` after the plugin name, or you can set them after the plugin has been installed using `docker plugin set katharostech/seaweedfs-volume-plugin VARIABLE_NAME=value`.

> **Note:** When configuring the plugin after installation, the plugin must first be disabled before you can set variables. There is no danger of accidentally setting variables while the plugin is enabled, though. Docker will simply tell you that it is not possible.

#### HOST

The hostname/ip address and port that will be used when connecting to the SeaweedFS filer.

> **Note:** The plugin runs in `host` networking mode. This means that even though it is in a container, it shares its network configuration with the host and should resolve all network addresses as the host system would.

**Default:** `localhost:8080`

#### MOUNT_OPTIONS

Options passed to the `weed mount` command when mounting SeaweedFS volumes.

**Default:** empty string

#### REMOTE_PATH

The path on the SeaweedFS filesystem that Docker volumes will be stored in. This path will be mounted for volume storage by the plugin and must exist on the SeaweedFS filesystem.

**Default:** `/docker/volumes`

#### ROOT_VOLUME_NAME

The name of the Root Volume. If specified, a special volume will be created of the given name will be created that will contain all of the SeaweedFS volumes. It is equivalent to mounting the whole of `REMOTE_PATH` on the SeaweedFS filesystem. See [Root Mount Option](#root-mount-option).

**Default:** empty string

#### LOG_LEVEL

Plugin logging level. Set to `DEBUG` to get more verbose log messages. Logs from Docker plugins can be found in the Docker log and will be suffixed with the plugin ID.

**Default:** `INFO`

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

This will install the Docker plugin from the `plugin` dirctory with the name `katharostech/seaweedfs-volume-plugin`.

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

> **Note:** The tests have not be migrated from the LizardFS version of this plugin. The information in this section about tests is straight from the LizardFS version and hasn't been tested after porting the plugin.

The automated tests for the plugin are run using a Docker-in-Docker container that creates a Dockerized SeaweedFS cluster to test the plugin against. When you run the test container, it will install the plugin inside the Docker-in-Docker container and proceed to create a Dockerized LizardFS cluster in it as well. A shell script is run that manipulates the plugin and runs containers to ensure the plugin behaves as is expected.

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
2f5b68535b92        katharostech/seaweedfs-volume-plugin:latest   SeaweedFS volume plugin for Docker   false
```

Using that ID you can find where the plugin's rootfs was installed. By default, it should be located in `/var/lib/docker/plugins/[pluginID]/rootfs`. For our particular plugin, the file that we need to replace is the `/project/index.js` file in the plugin's rootfs. By replacing that file with an updated version and restarting ( disabling and re-enabling ) the plugin, you can update the plugin without having to re-install it.

#### Exec-ing Into the Plugin Container

It may be useful during development to exec into the plugin container while it is running. You can find out how in the [Docker Documentation](https://docs.docker.com/engine/extend/#debugging-plugins).

#### Test Case Development

> **Note:** The tests have not be migrated from the LizardFS version of this plugin. The information in this section about tests is straight from the LizardFS version and hasn't been tested after porting the plugin.

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
