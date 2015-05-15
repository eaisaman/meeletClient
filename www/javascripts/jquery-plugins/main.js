requirejs.config(
    {
        paths: {
            "icheck": JQUERY_PLUGINS_LIB_PATH + "icheck/1.0.2/icheck.min",
            "sly": JQUERY_PLUGINS_LIB_PATH + "sly/1.2.7/sly"
        },
        shim: {
            "icheck": {deps: ["jquery-lib"]},
            "sly": {deps: ["jquery-lib"]}
        },
        waitSeconds: 0
    }
);

define(
    [
        "icheck", "sly"
    ],
    function () {
        [
            JQUERY_PLUGINS_LIB_PATH + "icheck/1.0.2/skins/" + "all.css"
        ].forEach(function (href) {
                var link = window.document.createElement("link");
                link.type = "text/css";
                link.rel = "stylesheet";
                link.href = href;
                window.document.getElementsByTagName("head")[0].appendChild(link);
            }
        );

        return function () {
        }
    }
);