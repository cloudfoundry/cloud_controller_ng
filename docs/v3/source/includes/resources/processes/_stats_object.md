### The process stats object

Name | Type | Description
---- | ---- | -----------
**type** | _string_ | Process type. A unique identifier for processes belonging to an app.
**index** | _integer_ | The zero-based index of running instances.
**state** | _string_ | The state of the instance. Valid values are `RUNNING`, `CRASHED`, `STARTING`, `DOWN`.
**usage.time** | _datetime_ | The time when the usage was requested.
**usage.cpu** | _number_ | The current cpu usage of the instance.
**usage.mem** | _integer_ | The current memory usage of the instance.
**usage.disk** | _integer_ | The current disk usage of the instance.
**host** | _string_ | The host the instance is running on.
**instance_ports** | _object_ | JSON array of port mappings between the network-exposed port used to communicate with the app (`external`) and port opened to the running process that it can listen on (`internal`).
**uptime** | _integer_ | The uptime in seconds for the instance.
**mem_quota** | _integer_ | The maximum memory the instance is allowed to use.
**disk_quota** | _integer_ | The maximum disk the instance is allowed to use.
**fds_quota** | _integer_ | The maximum file descriptors the instance is allowed to use.
