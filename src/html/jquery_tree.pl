:- module(jquery_tree, [load_jquery_tree/1]).

load_jquery_tree('\n<script type="text/javascript">\n(function($){\n    $.fn.treemenu = function(options) {\n        options = options || {};\n        options.delay = options.delay || 0;\n        options.openActive = options.openActive || false;\n        options.closeOther = options.closeOther || false;\n        options.activeSelector = options.activeSelector || ".active";\n\n        this.addClass("treemenu");\n\n        if (!options.nonroot) {\n            this.addClass("treemenu-root");\n        }\n\n        options.nonroot = true;\n\n        this.find("> li").each(function() {\n            e = $(this);\n            var subtree = e.find(\'> ul\');\n            var button = e.find(\'.toggler\').eq(0);\n\n            if(button.length == 0) {\n                // create toggler\n                var button = $(\'<span>\');\n                button.addClass(\'toggler\');\n                e.prepend(button);\n            }\n\n            if(subtree.length > 0) {\n                subtree.hide();\n\n                e.addClass(\'tree-closed\');\n\n                e.find(button).click(function() {\n                    var li = $(this).parent(\'li\');\n\n                    if (options.closeOther && li.hasClass(\'tree-closed\')) {\n                        var siblings = li.parent(\'ul\').find("li:not(.tree-empty)");\n                        siblings.removeClass("tree-opened");\n                        siblings.addClass("tree-closed");\n                        siblings.removeClass(options.activeSelector);\n                        siblings.find(\'> ul\').slideUp(options.delay);\n                    }\n\n                    li.find(\'> ul\').slideToggle(options.delay);\n                    li.toggleClass(\'tree-opened\');\n                    li.toggleClass(\'tree-closed\');\n                    li.toggleClass(options.activeSelector);\n                });\n\n                $(this).find(\'> ul\').treemenu(options);\n            } else {\n                $(this).addClass(\'tree-empty\');\n            }\n        });\n\n        if (options.openActive) {\n            var cls = this.attr("class");\n\n            this.find(options.activeSelector).each(function(){\n                var el = $(this).parent();\n\n                while (el.attr("class") !== cls) {\n                    el.find(\'> ul\').show();\n                    if(el.prop("tagName") === \'UL\') {\n                        el.show();\n                    } else if (el.prop("tagName") === \'LI\') {\n                        el.removeClass(\'tree-closed\');\n                        el.addClass("tree-opened");\n                        el.show();\n                    }\n\n                    el = el.parent();\n                }\n            });\n        }\n\n        return this;\n    }\n})(jQuery);\n</script>\n\n ').