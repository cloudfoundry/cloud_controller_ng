<div class='no-margin'></div>

## The app object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      guid
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Unique GUID for the app.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      name
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">An arbitrary name of the app.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      desired_state
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Current desired state of the app. Can either be <code>STOPPED</code> or <code>STARTED</code>.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      total_desired_instances
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">Number of desired instances of the application.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      lifecycle
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Provides the lifecycle object for the application.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      environment_variables
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Provides the list of custom environment variables available to the application.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      created_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the app was created.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      updated_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone with the app was last updated.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      links
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Links to related resources.</p>
  </li>
</ul>

