/* jquery Tocify - v1.8.0 - 2013-09-16
* http://www.gregfranko.com/jquery.tocify.js/
* Copyright (c) 2013 Greg Franko; Licensed MIT
* Modified lightly by Robert Lord to fix a bug I found,
* and also so it adds ids to headers
* also because I want height caching, since the
* height lookup for h1s and h2s was causing serious
* lag spikes below 30 fps */

(function(tocify) {
    "use strict";
    tocify(window.jQuery, window, document);
}

(function($, window, document, undefined) {
    "use strict";

    var tocFocusClassName = "toc-focus",
        tocHoverClassName = "toc-hover",
        headerClassName = "toc-header",
        headerClass = "." + headerClassName,
        subheaderClassName = "toc-subheader",
        subheaderClass = "." + subheaderClassName,
        itemClassName = "toc-link",
        itemClass = "." + itemClassName;

    $.widget("toc.tocify", {
        //Plugin version
        version: "1.8.0",

        // These options will be used as defaults
        options: {
            // **context**: Accepts String: Any jQuery selector
            // The container element that holds all of the elements used to generate the table of contents
            context: "body",

            // **selectors**: Accepts an Array of Strings: Any jQuery selectors
            // The element's used to generate the table of contents.  The order is very important since it will determine the table of content's nesting structure
            selectors: "h1, h2, h3",

            // **showEffectSpeed**: Accepts Number (milliseconds) or String: "slow", "medium", or "fast"
            // The time duration of the show animation
            showEffectSpeed: "medium",

            // **hideEffectSpeed**: Accepts Number (milliseconds) or String: "slow", "medium", or "fast"
            // The time duration of the hide animation
            hideEffectSpeed: "medium",

            // **scrollTo**: Accepts Number (pixels)
            // The amount of space between the top of page and the selected table of contents item after the page has been scrolled
            scrollTo: 0,

            // **highlightOffset**: Accepts a number
            // The offset distance in pixels to trigger the next active table of contents item
            highlightOffset: 1
        },

        _create: function() {
            var self = this;

            self.tocifyWrapper = $('.toc-wrapper');

            self.cachedHeights = [],
            self.cachedAnchors = [];

            self.focusClass = tocFocusClassName;
            self.hoverClass = tocHoverClassName;

            self._setEventHandlers();

            // Binding to the Window load event to make sure the correct scrollTop is calculated
            $(window).load(function() {
                self._setActiveElement(true);
            });
        },

        _setActiveElement: function(pageload) {
            var self = this;
            var hash = window.location.hash.substring(1);
            var elem = self.element.find(".toc-link[href='#" + hash + "']");

            self.element.find("." + self.focusClass).removeClass(self.focusClass);

            if (hash.length) {
                elem.addClass(self.focusClass);
                self._triggerShow(elem);
            } else if (pageload) {
                self.element.find(itemClass).first().addClass(self.focusClass);
            }

            return self;
        },

        _setEventHandlers: function() {
            var self = this;

            this.element.on("click.tocify", "a", function() {
                self.element.find("." + self.focusClass).removeClass(self.focusClass);
                $(this).addClass(self.focusClass);
            });

            $(window).on('resize', function() {
                self._calculateHeights();
            });

            $(window).on("scroll.tocify", function() {
                // Once all animations on the page are complete, this callback function will be called
                $("html, body").promise().done(function() {
                    // The zero timeout ensures the following code is run after the scroll events
                    setTimeout(function() {
                        if (self.cachedHeights.length == 0) {
                            self._calculateHeights();
                        }

                        var scrollTop = $(window).scrollTop();

                        var closestAnchorIdx = null;
                        self.cachedAnchors.each(function(idx) {
                            if (self.cachedHeights[idx] - scrollTop < 0) {
                                closestAnchorIdx = idx;
                            } else {
                                return false;
                            }
                        });

                        var anchorText = $(self.cachedAnchors[closestAnchorIdx]).attr("id");
                        var elem = $('.toc-link[href="#' + anchorText + '"]');

                        if (elem.length && !elem.hasClass(self.focusClass)) {
                            self.element.find("." + self.focusClass).removeClass(self.focusClass);
                            elem.addClass(self.focusClass);
                        }

                        if (window.location.hash !== "#" + anchorText && anchorText !== undefined) {
                            history.replaceState({}, "", "#" + anchorText);
                        }

                        self._triggerShow(elem);
                    }, 0);
                });
            });
        },

        _calculateHeights: function() {
            var self = this;
            self.cachedAnchors = $(self.options.context).find(self.options.selectors);
            self.cachedHeights = [];

            self.cachedAnchors.each(function(idx) {
                self.cachedHeights[idx] = $(this).offset().top - self.options.highlightOffset;
            });
        },

        _show: function(elem) {
            var self = this;
            var parent = elem.parent()

            if (!elem.is(":visible")) {
                // If the current element does not have any nested subheaders, is not a header, and its parent is not visible
                if (!elem.find(subheaderClass).length && !parent.is(headerClass) && !parent.is(":visible")) {
                    // Sets the current element to all of the subheaders within the current header
                    elem = elem.parents(subheaderClass).add(elem);
                }

                // If the current element does not have any nested subheaders and is not a header
                else if (!elem.children(subheaderClass).length && !parent.is(headerClass)) {
                    // Sets the current element to the closest subheader
                    elem = elem.closest(subheaderClass);
                }

                elem.slideDown(self.options.showEffectSpeed);
            }

            // If the current subheader parent element is a header
            if (parent.is(headerClass)) {
                // Hides all non-active sub-headers
                self.hide($(subheaderClass).not(elem));
            }

            // If the current subheader parent element is not a header
            else {
                // Hides all non-active sub-headers
                self.hide($(subheaderClass).not(elem.closest(headerClass).find(subheaderClass).not(elem.siblings())));
            }

            return self;
        },

        hide: function(elem) {
            var self = this;

            elem.slideUp(self.options.hideEffectSpeed);

            return self;
        },

        _triggerShow: function(linkElem) {
            var self = this;
            var itemElem = linkElem.parent();

            if (itemElem.parent().is(headerClass) || itemElem.next().is(subheaderClass)) {
                // Shows the next sub-header element
                self._show(itemElem.next(subheaderClass));
            } else if (itemElem.parent().is(subheaderClass)) {
                // Shows the parent sub-header element
                self._show(itemElem.parent());
            }

            return self;
        },

        setOption: function() {
            $.Widget.prototype._setOption.apply(this, arguments);
        }
    });
}));
