<!-- We need to use plain html here to specify different ids. Otherwise the framework will mess up urls -->
<h3 id="builds-v3">Builds</h3>

Builds increase the flexibility and granularity of control available
to clients crafting stagings workflows. For example:

- Staging older packages instead of always staging the most recent package
- Staging packages without having to stop an application
- Staging packages to produce droplets without setting them as the current
  droplet for an app
- Staging packages into droplets for use in tasks and/or rolling deployments

Read more about the [builds resource](#builds).
