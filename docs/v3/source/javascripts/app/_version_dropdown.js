(function() {
  'use strict';

  $(setupVersionsDropdown);

  function setupVersionsDropdown() {
    $.get(
      "/versions.json",
      function(data) {
        var versions = data.versions;

        for (var i = 0; i < versions.length; i++) {
          var version = versions[i];
          if (version == "release-candidate") continue;

          var li = '<li><a id="version-link-' + version + '"' + ' class="version-link" href="/version/' + version + '">' + version + '</a></li>';
          $('#version-list').append(li);
        }
      }
    );
  }
})();

