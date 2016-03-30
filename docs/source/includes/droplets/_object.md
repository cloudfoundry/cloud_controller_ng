<div class='no-margin'></div>

## The droplet object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      guid
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Unique GUID for the droplet.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      state
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">
      State of the package. Possible states are "PENDING", "STAGING", "STAGED", "FAILED", or "EXPIRED".
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      error
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">
      A string describing the last error during the droplet lifecycle.
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      lifecycle
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">
      An object describing the lifecycle that was configured or discovered.
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      memory_limit
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">
      The maximum memory in mb that can be used by a droplet.
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      disk_limit
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">
      The disk quota applied during droplet staging.
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      result
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">
      An object describing the result of a droplet that has completed staging (where state is
      "STAGED", "FAILED", or "EXPIRED"). Droplets in uncomplete states return null result.
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      environment_variables
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">
      Environment variables to be used when staging the droplet. Variables in the <code>CF_</code>
      and <code>VCAP_</code> scopes will be populated by the system. 
    </p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      created_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the package was created.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      updated_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone with the package was last updated.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      links
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Links to related resources.</p>
  </li>
</ul>

