define(
    ["angular", "jquery", "jquery-ui", "app-route", "app-service"],
    function () {
        return function (appModule, extension) {
            function RootController($scope, $rootScope, $q, angularConstants, angularEventTypes, appService, urlService, uiUtilService) {

                function initMaster() {
                    window.onProjectScan = function (projectId) {
                        $rootScope.$broadcast(angularEventTypes.projectScanEvent, {projectId: projectId});
                    }

                    window.onDownloadProjectStart = function (projectId, mode) {
                        $rootScope.$broadcast(angularEventTypes.downloadProjectStartEvent, {
                            projectId: projectId,
                            mode: mode
                        });
                    }

                    window.onDownloadProjectDone = function (projectId) {
                        $rootScope.$broadcast(angularEventTypes.downloadProjectDoneEvent, {projectId: projectId});
                    }

                    window.onDownloadProjectError = function (projectId, mode, err) {
                        $rootScope.$broadcast(angularEventTypes.downloadProjectErrorEvent, {
                            projectId: projectId,
                            mode: mode,
                            err: err
                        });
                    }

                    window.onDownloadProjectProgress = function (projectId, progress) {
                        $rootScope.$broadcast(angularEventTypes.downloadProjectProgressEvent, {
                            projectId: projectId,
                            progress: progress
                        });
                    }

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
                                            return appService.doLogin("wangxinyun28", "*").then(
                                                function (result) {
                                                    if (result && result.data.result == "OK") {
                                                        var userObj = result.data.resultValue[0];
                                                        userObj && _.extend($rootScope.loginUser, userObj);
                                                    }

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
                                    return appService.getUserDetail({"loginName": "wangxinyun28"}).then(
                                        function (result) {
                                            result && result.data.result == "OK" && _.extend($rootScope.userDetail, result.data.resultValue[0]);

                                            $rootScope.userDetail.projectList[0].mode = "waitDownload";
                                            $rootScope.userDetail.projectList[0].progress = 15;
                                            $rootScope.userDetail.projectList[1].mode = "inProgress";
                                            $rootScope.userDetail.projectList[1].progress = 25;

                                            return uiUtilService.getResolveDefer();
                                        },
                                        function (err) {
                                            return uiUtilService.getRejectDefer(err);
                                        }
                                    );
                                });

                                arr.push(function () {
                                    return appService.getLocalProject().then(function (result) {
                                            result && result.data.result == "OK" && Array.prototype.splice.apply($rootScope.userDetail.projectList, Array.prototype.concat.apply(Array.prototype, [0, 0, result.data.resultValue]));

                                            return uiUtilService.getResolveDefer();
                                        },
                                        function (err) {
                                            return uiUtilService.getRejectDefer(err);
                                        });
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

            function ProjectController($scope, $rootScope, $timeout, $q, angularConstants, angularEventTypes, appService, uiService, urlService, uiUtilService) {
                extension && extension.attach && extension.attach($scope, {
                    "$timeout": $timeout,
                    "$q": $q,
                    "angularConstants": angularConstants,
                    "uiUtilService": uiUtilService,
                    "element": $(".projectContainer"),
                    "scope": $scope
                });

                $scope.displayProjectModal = function (event) {
                    event && event.stopPropagation && event.stopPropagation();

                    var scope = angular.element($("#projectContainer > .modalWindowContainer > .md-modal")).scope();
                    scope.toggleModalWindow();

                    return true;
                }

                $scope.hideProjectModal = function (event) {
                    event && event.stopPropagation && event.stopPropagation();

                    var scope = angular.element($("#projectContainer > .modalWindowContainer .md-modal")).scope();
                    scope.toggleModalWindow();
                }

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

                $scope.createProjectKnob = function (projectItem) {
                    uiUtilService.whilst(
                        function () {
                            return !document.getElementById(projectItem._id);
                        },
                        function (callback) {
                            callback();
                        },
                        function (err) {
                            if (!err) {
                                $("#{0} .projectItemProgress input.projectItemKnob".format(projectItem._id)).knob({});
                            }
                        },
                        angularConstants.checkInterval,
                        "ProjectController.createProjectKnob." + projectItem._id,
                        angularConstants.renderTimeout
                    );
                }

                //Project Item mode: 1.Wait Download; 2.Wait Refresh; 3. Download or Refresh in Progress
                $scope.downloadProject = function (projectItem, event) {
                    event && event.stopPropagation && event.stopPropagation();

                    appService.downloadProject(projectItem._id);
                }

                $scope.pauseDownloadProject = function (projectItem, event) {
                    event && event.stopPropagation && event.stopPropagation();

                    appService.pauseDownloadProject(projectItem._id);
                }

                function initMaster() {
                    $scope.$on(angularEventTypes.projectScanEvent, function (event, data) {
                        $timeout(function () {
                            $scope.displayProjectModal();

                            if ($scope.userDetail.projectList.every(function (projectItem) {
                                    if (projectItem._id === data.projectId) {
                                        $scope.pickedProject = projectItem;
                                        return false;
                                    }

                                    return true;
                                })) {
                                appService.getProject({_id: data.projectId}).then(
                                    function (result) {
                                        if (result && result.data.result == "OK" && result.data.resultValue.length) {
                                            $scope.pickedProject = result.data.resultValue[0];
                                        }
                                    },
                                    function (err) {
                                    }
                                );
                            }
                        });

                        $scope.$apply();
                    });

                    $scope.$on(angularEventTypes.downloadProjectStartEvent, function (event, data) {
                        $timeout(function () {
                            $scope.userDetail.projectList.every(function (projectItem) {
                                if (projectItem._id === data.projectId) {
                                    projectItem.mode = data.mode;
                                    return false;
                                }

                                return true;
                            });
                        });

                        $scope.$apply();
                    });

                    $scope.$on(angularEventTypes.downloadProjectDoneEvent, function (event, data) {
                        $timeout(function () {
                            $scope.userDetail.projectList.every(function (projectItem) {
                                if (projectItem._id === data.projectId) {
                                    projectItem.mode = "waitRefresh";
                                    return false;
                                }

                                return true;
                            });
                        });

                        $scope.$apply();
                    });

                    $scope.$on(angularEventTypes.downloadProjectErrorEvent, function (event, data) {
                        $timeout(function () {
                            $scope.userDetail.projectList.every(function (projectItem) {
                                if (projectItem._id === data.projectId) {
                                    projectItem.mode = data.mode;
                                    return false;
                                }

                                return true;
                            });
                        });

                        $scope.$apply();
                    });

                    $scope.$on(angularEventTypes.downloadProjectProgressEvent, function (event, data) {
                        $timeout(function () {
                            $scope.userDetail.projectList.every(function (projectItem) {
                                if (projectItem._id === data.projectId) {
                                    projectItem.progress = data.progress;
                                    return false;
                                }

                                return true;
                            });
                        });

                        $scope.$apply();
                    });

                    return $q.all([appService.checkProjectExist(_.pluck($scope.userDetail.projectList, "_id"))]).then(
                        function (result) {
                            if (result[0] && result[0].data.result == "OK") {
                                result[0].data.resultValue.forEach(function (mode, i) {
                                    $scope.userDetail.projectList[i].mode = mode;
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
                controller('RootController', ["$scope", "$rootScope", "$q", "angularConstants", "angularEventTypes", "appService", "urlService", "uiUtilService", RootController]).
                controller('ProjectController', ["$scope", "$rootScope", "$timeout", "$q", "angularConstants", "angularEventTypes", "appService", "uiService", "urlService", "uiUtilService", ProjectController]);
        }
    }
);