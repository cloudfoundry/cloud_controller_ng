<div class='no-margin'></div>

## The lifecycle object

Lifecycle objects describe buildpacks or docker images.

### Lifecycle object for buildpack droplets

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      type
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">"buildpack"</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      data['buildpack']
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">
      The name of the buildpack or a URL from which it may be downloaded, or null
      to auto-detect the buildpack
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      data['stack']
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">
      The root filesystem to use with the buildpack, for example "cflinuxfs2"
    </p>
  </li>
</ul>

### Lifecycle object for docker

Droplets created with a docker lifecycle are only valid for docker packages.

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      type
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">"docker"</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      data
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">
      An empty object should be passed: "{}"
    </p>
  </li>
</ul>
