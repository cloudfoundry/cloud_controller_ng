### App Sub-Resources

The V2 API rolls up several resources into its representation of an "app":

1. **Packages:** Source assets for the application
2. **Droplets:** Staged, executable assets for the application
3. **Builds:** Configuration for how to stage the package into a droplet
4. **Processes:** Configuration for how to run the droplet

The V3 API exposes these resources on the API to provide more visibility and enable more complicated workflows. For example:

1. Staging a previous package into a new droplet
2. Rolling back to a previous droplet
3. Staging a droplet to run a task, without running any processes
4. Running multiple different processes from a single droplet (for example: a web process and a worker process)

Here are some examples of implications for clients:

1. The app resource contains much less information about the application as a whole
2. An application can have multiple processes, each with their own start command. The processes can be scaled independently, and stats be retrieved independently.
3. An application might not be running with its most recent package or droplet
