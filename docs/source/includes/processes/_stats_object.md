<div class='no-margin'></div>

## The process stats object

<ul class="method-list-group">
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      type
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">Process type. A unique identifier for processes belonging to an app.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      index
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The zero-based index of running intances.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      state
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">The state of the instance. RUNNING, CRASHED, STARTING</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      usage['time']
      <span class="method-list-item-type">datetime</span>
    </h4>

    <p class="method-list-item-description">The time when the usage was requested.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      usage['cpu']
      <span class="method-list-item-type">number</span>
    </h4>

    <p class="method-list-item-description">The current cpu usage of the instance.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      usage['mem']
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The current memory usage of the instance.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      usage['disk']
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The current disk usage of the instance.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      host
      <span class="method-list-item-type">string</span>
    </h4>

    <p class="method-list-item-description">The host the instance is running on.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      instance_ports
      <span class="method-list-item-type">object</span>
    </h4>

    <p class="method-list-item-description">JSON array of port mappings between the network-exposed port used to communicate with the app ("external") and port opened to the running process that it can listen on ("internal").</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      uptime
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The uptime in seconds for the instance.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      mem_quota
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The maximum memory the instance is allowed to use.</p>
  </li>
  <li class="method-list-item">
    <h4 class="method-list-item-label">
      disk_quota
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The maximum disk the instance is allowed to use.</p>
  </li>
   <li class="method-list-item">
    <h4 class="method-list-item-label">
      fds_quota
      <span class="method-list-item-type">integer</span>
    </h4>

    <p class="method-list-item-description">The maximum file descriptors the instance is allowed to use.</p>
  </li>
</ul>

