//= require ../lib/_lunr
(function () {
  'use strict';

  var searchInput, searchResults;

  var index = new lunr.Index();
  index.ref('id');
  index.field('title', { boost: 10 });
  index.pipeline.add(lunr.trimmer, lunr.stopWordFilter);

  $(populate);
  $(bind);
  $(initializeSlashHandler);

  function populate() {
    $('h1, h2, h3').each(function() {
      var title = $(this);
      index.add({
        id: title.prop('id'),
        title: title.text()
      });
    });
  }

  function bind() {
    searchInput = $('#input-search');
    searchResults = $('.search-results');
    searchInput.on('keyup', search);
  }

  function initializeSlashHandler() {
    $('body').on('keydown', function(event) {
      if (event.keyCode == 191 && !searchInput.is(':focus')) {
        event.preventDefault();
        searchResults.empty();
        searchInput.val('').focus();
      }
    });
  }

  function search(event) {
    searchResults.addClass('visible');

    // ESC clears the field
    if (event.keyCode === 27) this.value = '';

    if (this.value) {
      var results = index.search(this.value).filter(function(r) {
        return r.score > 0.0001;
      });

      if (results.length) {
        searchResults.empty();
        $.each(results, function (index, result) {
          var elemId = '#' + result.ref;
          searchResults.append("<li><a href='" + elemId + "'>" + $(elemId).text() + "</a></li>");
        });
      } else {
        searchResults.html('<li>No results found for "' + this.value + '"</li>');
      }
    } else {
      searchResults.removeClass('visible');
    }
  }
})();
