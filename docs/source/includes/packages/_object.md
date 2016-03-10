<div class='no-margin'></div>

## The package object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      guid
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Unique GUID for the package</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      type
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Package type. Possible values are "bits", "docker".</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      data
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Data for docker packages. Can be empty for bits packages.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      state
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">State of the package. Possible states are "PROCESSING_UPLOAD", "READY", "FAILED", "AWAITING_UPLOAD", "COPYING", and "EXPIRED".</p>
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

