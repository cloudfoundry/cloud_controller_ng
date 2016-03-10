<div class='no-margin'></div>

## The service_binding object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      guid
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Unique GUID for the service binding</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      type
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Service binding type. Currently only possible value is "app".</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      data
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Data returned from the service broker for the service instance. Currently possible values are "credentials" and "syslog_drain_url".</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      created_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the service binding was created.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      updated_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the service binding was last updated.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      links
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Links to related resources.</p>
  </li>
</ul>

