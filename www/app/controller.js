define(
    ["angular", "jquery", "jquery-ui", "app-route", "app-service"],
    function () {
        return function (appModule, extension) {
            function RootController($scope, $rootScope, $q, angularConstants, appService, urlService, uiUtilService) {

                function initMaster() {
                    $rootScope.userDetail = {projectList: []};

                    return appService.getServerUrl().then(function (serverUrl) {
                        angularConstants.serverUrl = serverUrl || "";

                        //For development convenience, we do fake login or restore user info if already authenticated.
                        return appService.restoreUserFromStorage().then(
                            function () {
                                var arr = [];
                                if (!$rootScope.loginUser._id) {
                                    arr.push(
                                        function () {
                                            return appService.doLogin("xujingkai27", "*").then(
                                                function (userObj) {
                                                    userObj && _.extend($rootScope.loginUser, userObj);

                                                    return uiUtilService.getResolveDefer();
                                                },
                                                function (err) {
                                                    return uiUtilService.getRejectDefer(err);
                                                }
                                            )
                                        }
                                    );
                                }

                                arr.push(function () {
                                    return appService.getUserDetail({"loginName": "xujingkai27"}).then(
                                        function (result) {
                                            result && result.data.result == "OK" && _.extend($rootScope.userDetail, result.data.resultValue[0]);

                                            return uiUtilService.getResolveDefer();
                                        },
                                        function (err) {
                                            return uiUtilService.getRejectDefer(err);
                                        }
                                    );
                                });

                                return uiUtilService.chain(arr).then(
                                    function (err) {
                                        if (err) {
                                            return uiUtilService.getRejectDefer(err);
                                        } else {
                                            return uiUtilService.getResolveDefer();
                                        }
                                    }
                                );
                            }, function (err) {
                                return uiUtilService.getRejectDefer(err);
                            }
                        );
                    });
                }

                initMaster().then(
                    function () {
                        urlService.firstPage();
                    }
                    //TODO Redirect to default error.html
                );
            }

            function ProjectController($scope, $rootScope, $timeout, $q, angularConstants, appService, uiService, urlService, uiUtilService) {
                extension && extension.attach && extension.attach($scope, {
                    "$timeout": $timeout,
                    "$q": $q,
                    "angularConstants": angularConstants,
                    "uiUtilService": uiUtilService,
                    "element": $(".projectContainer"),
                    "scope": $scope
                });

                $scope.scanProjectCode = function (event) {
                    event && event.stopPropagation && event.stopPropagation();

                    appService.scanProjectCode();
                }

                $scope.toggleProjectButton = function (event) {
                    event && event.stopPropagation && event.stopPropagation();

                    var $el = $(event.target);
                    !$el.hasClass("select") && $(".topbarToggleButton.select").removeClass("select");
                    $el.toggleClass("select");
                    $scope.toggleCheckMode = $el.hasClass("select");

                    $scope.userDetail.projectList.forEach(function (projectItem) {
                        projectItem.checked = false;
                    });
                }

                $scope.toggleCheck = function (projectItem, event) {
                    event && event.stopPropagation && event.stopPropagation();

                    projectItem.checked = !projectItem.checked;
                    !projectItem.checked && delete projectItem.checked;
                }

                $scope.confirmProjectAction = function (event) {
                    event && event.stopPropagation && event.stopPropagation();
                }

                $scope.cancelProjectAction = function (event) {
                    event && event.stopPropagation && event.stopPropagation();
                }

                function initMaster() {
                    return $q.all([appService.checkProjectExist(_.pluck($scope.userDetail.projectList, "_id"))]).then(
                        function (result) {
                            if (result[0] && result[0].data.result == "OK") {
                                result[0].data.resultValue.forEach(function (exist, i) {
                                    $scope.userDetail.projectList[i].exist = exist;
                                });
                            }

                            return uiUtilService.getResolveDefer();
                        },
                        function (err) {
                            return uiUtilService.getRejectDefer(err);
                        }
                    );
                }

                initMaster();
            }

            appModule.
                controller('RootController', ["$scope", "$rootScope", "$q", "angularConstants", "appService", "urlService", "uiUtilService", RootController]).
                controller('ProjectController', ["$scope", "$rootScope", "$timeout", "$q", "angularConstants", "appService", "uiService", "urlService", "uiUtilService", ProjectController]);
        }
    }
);