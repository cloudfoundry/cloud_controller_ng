If your cloud controller is in a bad state (infinite loop, resource spike,
etc.), you may wish to do a diagnostic dump to get more information than is
available in the CF logs. This data includes stack traces for running threads
and other general metrics.

1. SSH into the rogue Cloud Controller’s vm
2. `cat /var/vcap/sys/run/cloud_controller_ng/cloud_controller_ng.pid` to get
   the PID of the process
3. `kill -USR1 [pid]` You will need root access. This will NOT terminate the CC process.
4. The diagnostics directory is likely
   `/var/vcap/data/cloud_controller_ng/diagnostics`, but if it is not, look for
   the diagnostics key in
   `/var/vcap/jobs/cloud_controller_ng/config/cloud_controller_ng.yml`
5. In the diagnostics directory, you will find a json file with diagnostic information.
