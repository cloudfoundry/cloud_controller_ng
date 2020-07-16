## Deprecated Endpoints

The specialized `/v2/apps/:guid/restage` endpoint is replaced by the
[builds](#builds) resource. Builds allow finer-grained control and increased
flexibility when staging packages into droplets. The V3 API avoids making
assumptions about which package/droplet to use when staging or running an app
and thus leaves it up to clients.
