//= require ../lib/_lunr
(function () {
  'use strict';

  var content, searchResults;

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
    content = $('.content');
    searchResults = $('.search-results');

    $('#input-search').on('keyup', search);
  }

  function initializeSlashHandler() {
    $('body').on('keydown', function(event) {
      if (event.keyCode == 191) {
        event.preventDefault();
        $('#input-search').val('').focus();
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
          var elem = document.getElementById(result.ref);
          searchResults.append("<li><a href='#" + result.ref + "'>" + $(elem).text() + "</a></li>");
        });
      } else {
        searchResults.html('<li></li>');
        $('.search-results li').text('No results found for "' + this.value + '"');
      }
    } else {
      searchResults.removeClass('visible');
    }
  }
})();
