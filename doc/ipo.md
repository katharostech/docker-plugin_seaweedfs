# IPO Outline

This document outlines the basic Input-Process-Output flow of the volume plugin.

## Environment

The LizardFS  Docker plugin implements the [Docker Plugin API](https://docs.docker.com/engine/extend/plugin_api/). The Inputs to the program are requests made by the Docker daemon to the plugin. Request such as `Plugin.Activate`, and `VolumeDriver.Create`, will be sent by the Docker daemon to the the unix socket, `/run/docker/plugins/lizardfs.sock`, and the LizardFS Docker plugin will process the request, take the required actions, and respond with an appropriate response.

## Requests

These are the requests that Docker will make to the plugin over the Unix socket. All requests will be HTTP POST requests and may contain a JSON payload. The plugin's response to the request should also be a JSON payload if applicable. Details about these requests can be found in the Docker documentation for the [Plugins API](https://docs.docker.com/engine/extend/plugin_api/) and the [Volume Plugin API](https://docs.docker.com/engine/extend/plugins_volume/#volumedrivercapabilities).

### /Plugin.Activate

#### Input

Empty payload.

#### Process

* Mount a subpath of the LizardFS filesystem specified by the `REMOTE_PATH` environment variable ( `/docker/volumes` by default) to `/mnt/lizardfs`. This is where the docker volumes will be stored. The `/mnt/lizardfs` directory will be referred to as the "volume root" throughout this document.

#### Output

```json
{
    "Implements": ["VolumeDriver"]
}
```

### /VolumeDriver.Create

#### Input

```json
{
    "Name": "volume_name",
    "Opts": {
      "ReplicationGoal": "replication_goal_number_or_name"
    }
}
```

#### Process

* Create sub-directory of volume root with the given `Name`. For example, `/mnt/lizardfs/volume_name`.
* Use `lizardfs setgoal` to set the replication goal for that Docker Volume to the value specified in the `Opts` ( if specified ).

#### Output

Error message ( if one occurred ).

```json
{
    "Err": ""
}
```

### /VolumeDriver.Remove

#### Input

```json
{
    "Name": "volume_name"
}
```

#### Process

* Delete the directory in the volume root with the given `Name`. For example, `/mnt/lizardfs/volume_name`.

#### Output

Error message ( if one occurred ).

```json
{
    "Err": ""
}
```

### /VolumeDriver.Mount

#### Input

```json
{
    "Name": "volume_name",
    "ID": "b87d7442095999a92b65b3d9691e697b61713829cc0ffd1bb72e4ccd51aa4d6c"
}
```

#### Process

* Create a directory outside of the LizardFS root mountpoint using the given `Name`, such as `/mnt/docker-volumes/volume_name`.
* Mount the subpath of the LizardFS filesystem ( for example, `/docker/volumes/volume_name` ) to the newly created mountpoint.
* Add the `ID` to the list of containers that have mounted `Name` in the `mounted_volumes` Javascript object. This variable is used to keep track of which containers have mounted the volume.

#### Output

We need to tell Docker where we mounted the volume or give an error message if there was a problem.

```json
{
    "Mountpoint": "/mnt/docker-volumes/volume_name",
    "Err": ""
}
```

### /VolumeDriver.Path

#### Input

```json
{
    "Name": "volume_name"
}
```

#### Process

* Determine the path at which the volume is mounted based on the `Name`.

#### Output

Error message ( if one occurred ).

```json
{
    "Mountpoint": "/mnt/docker-volumes/volume_name",
    "Err": ""
}
```

### /VolumeDriver.Unmount

#### Input

```json
{
    "Name": "volume_name",
    "ID": "b87d7442095999a92b65b3d9691e697b61713829cc0ffd1bb72e4ccd51aa4d6c"
}
```

#### Process

* Remove the `ID` from the list of containers that have mounted `Name` in `mounted_volumes` Javascript variable.
* If there are no containers in the list anymore, unmount the `/mnt/docker-volumes/volume_name` because it no longer needs to be mounted.

#### Output

Error message ( if one occurred ).

```json
{
    "Err": ""
}
```

### /VolumeDriver.Get

#### Input

```json
{
    "Name": "volume_name"
}
```

#### Process

* Make sure the volume exists: check that the directory of the name `volume_name` exists and that the process has read-write access.
* If the volume is mounted, return the mountpoint as well as the name.

#### Output

Return the volume name

```json
{
  "Volume": {
    "Name": "volume_name",
    "Mountpoint": "/mnt/docker-volumes/volume_name",
  },
  "Err": "Error if directory doesn't exist or we don't have read-write access to it."
}
```

### /VolumeDriver.List

#### Input

```json
{}
```

#### Process

* Get a list of the directories in the volume root: `/mnt/lizardfs/`.
* If the volume is mounted on the host, provide the `Mountpoint`.

#### Output

Error message ( if one occurred ).

```json
{
  "Volumes": [
    {
      "Name": "volume_name",
      "Mountpoint": "/mnt/docker-volumes/volume_name"
    }
  ],
  "Err": ""
}
```

### /VolumeDriver.Capabilities

#### Input

```json
{}
```

#### Process

Not applicable.

#### Output

```json
{
  "Capabilities": {
    "Scope": "global"
  }
}
```
