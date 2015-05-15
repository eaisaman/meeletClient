define(
    ["angular", "jquery", "jquery-ui", "app-route", "app-service"],
    function () {
        return function (appModule, extension) {
            function RootController($scope, $rootScope, $q, appService, urlService) {
                urlService.firstPage();
            }

            appModule.
                controller('RootController', ["$scope", "$rootScope", "$q", "appService", "urlService", RootController]);
        }
    }
);