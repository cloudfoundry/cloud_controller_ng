(function() {
  'use strict';

  // Theme management
  var STORAGE_KEY = 'docs-theme';
  var THEME_AUTO = 'auto';
  var THEME_LIGHT = 'light';
  var THEME_DARK = 'dark';

  function getSystemTheme() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return THEME_DARK;
    }
    return THEME_LIGHT;
  }

  function getStoredTheme() {
    try {
      return localStorage.getItem(STORAGE_KEY) || THEME_AUTO;
    } catch (e) {
      return THEME_AUTO;
    }
  }

  function setStoredTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch (e) {
      // localStorage might be disabled
    }
  }

  function applyTheme(theme) {
    var effectiveTheme = theme;

    if (theme === THEME_AUTO) {
      effectiveTheme = getSystemTheme();
      document.documentElement.removeAttribute('data-theme');
    } else {
      document.documentElement.setAttribute('data-theme', theme);
    }

    updateToggleButton(theme);
  }

  function updateToggleButton(currentTheme) {
    var button = document.getElementById('theme-toggle');
    if (!button) return;

    var icon = button.querySelector('.theme-icon');
    if (!icon) return;

    // Update icon and title based on current theme
    if (currentTheme === THEME_AUTO) {
      var systemTheme = getSystemTheme();
      icon.textContent = systemTheme === THEME_DARK ? '☀' : '☾';
      button.title = 'Theme: Auto (' + (systemTheme === 'dark' ? 'Dark' : 'Light') + ')';
    } else if (currentTheme === THEME_LIGHT) {
      icon.textContent = '☾';
      button.title = 'Theme: Light (click for Dark)';
    } else {
      icon.textContent = '☀';
      button.title = 'Theme: Dark (click for Auto)';
    }
  }

  function cycleTheme() {
    var current = getStoredTheme();
    var next;

    // Cycle: auto -> light -> dark -> auto
    if (current === THEME_AUTO) {
      next = THEME_LIGHT;
    } else if (current === THEME_LIGHT) {
      next = THEME_DARK;
    } else {
      next = THEME_AUTO;
    }

    setStoredTheme(next);
    applyTheme(next);
  }

  // Initialize theme on page load
  function initTheme() {
    var stored = getStoredTheme();
    applyTheme(stored);

    // Listen for system theme changes
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addListener(function() {
        var currentStored = getStoredTheme();
        if (currentStored === THEME_AUTO) {
          applyTheme(THEME_AUTO);
        }
      });
    }

    // Set up toggle button click handler
    var button = document.getElementById('theme-toggle');
    if (button) {
      button.addEventListener('click', function(e) {
        e.preventDefault();
        cycleTheme();
      });
    }
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initTheme);
  } else {
    initTheme();
  }
})();
