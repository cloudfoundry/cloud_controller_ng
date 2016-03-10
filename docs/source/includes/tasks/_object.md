<div class='no-margin'></div>

## The task object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      guid
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Unique GUID for the task</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      name
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">User-facing name of the task.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      command
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Command that will be executed</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      environment_variables
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Environment variables set on the
    container running your task.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      memory_in_mb
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">Maximum memory for the task in MB.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      state
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">State of the task. Possible states are PENDING, RUNNING, SUCCEEDED, CANCELING, and FAILED</p>
  </li>
  <li class="method-list-item">
      <h4 class="method-list-item-label">
        result
        <span class="method-list-item-type">object</span>
      </h4>

      <p class="method-list-item-description">Results from the task</p>
  </li>
  <li class="method-list-item">
      <h4 class="method-list-item-label">
        result[failure_reason]
        <span class="method-list-item-type">string</span>
      </h4>

      <p class="method-list-item-description">Null if the task succeeds, contains the error message if it fails.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      created_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the task was created.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      updated_at
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time with zone when the task was last updated.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      links
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">Links to related resources.</p>
  </li>
</ul>

