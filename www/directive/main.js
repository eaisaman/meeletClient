requirejs.config(
    {
        paths: {
            "ng.ui.util": DIRECTIVE_LIB_PATH + "ng.ui.util",
            "ng.ui.service": DIRECTIVE_LIB_PATH + "ng.ui.service",
            "ng.ui.extension": DIRECTIVE_LIB_PATH + "ng.ui.extension",
            "ng.ui.hammer-gestures": DIRECTIVE_LIB_PATH + "ng.ui.hammer-gestures",
            "ng.ui.draggable": DIRECTIVE_LIB_PATH + "ng.ui.draggable",
            "widget.anchor": DIRECTIVE_LIB_PATH + "widget.anchor"
        }
    }
);


define([
        "ng.ui.util",
        "ng.ui.service",
        "ng.ui.extension",
        "ng.ui.hammer-gestures",
        "ng.ui.draggable",
        "widget.anchor"
    ],
    function () {
        var utilConfig = arguments[0],
            serviceConfig = arguments[1],
            extension = arguments[2],
            directiveConfigs = Array.prototype.slice.call(arguments, 3);

        return function (appModule) {
            utilConfig(appModule);

            serviceConfig(appModule);

            //Hammer gestures
            directiveConfigs[0](appModule);

            //Draggable directive
            directiveConfigs[1](appModule);

            //widget-anchor directive
            directiveConfigs[2](appModule);
        }
    }
);