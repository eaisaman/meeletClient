define(
    ["angular"],
    function () {
        return function (appModule, locations) {
            var needGoBack = true;

            var urlService = function ($location, $rootScope) {
                this.$location = $location;
                this.$rootScope = $rootScope;
                this.$rootScope.urlStack = [];
                this.locations = [];
                this.addLocation(locations);
            };

            urlService.$inject = ["$location", "$rootScope"];

            urlService.prototype.currentLocation = function () {
                if (this.$rootScope.urlStack.length) {
                    return this.$rootScope.urlStack[this.$rootScope.urlStack.length - 1].location;
                } else {
                    return "";
                }
            }
            urlService.prototype.back = function () {
                if (this.$rootScope.urlStack.length > 1) {
                    var urlObj = this.$rootScope.urlStack.pop();
                    delete this.$rootScope.urlParams[urlObj.location];

                    urlObj = this.$rootScope.urlStack[this.$rootScope.urlStack.length - 1];
                    urlObj.fn.apply(this, [urlObj.location, true, this.$rootScope.urlParams[urlObj.location]]);
                }
            }
            urlService.prototype.home = function (needLoad) {
                if (this.$rootScope.urlStack.length > 1) {
                    this.clearUrlStack(this.$rootScope.urlStack.length - 1);

                    if (needLoad == null || needLoad) {
                        var urlObj = this.$rootScope.urlStack[0];
                        urlObj.fn.apply(this, [urlObj.location, true, this.$rootScope.urlParams[urlObj.location]]);
                    }
                }
            }
            urlService.prototype.clearUrlStack = function (depth) {
                var self = this;

                depth = Math.min(depth || self.$rootScope.urlStack.length, self.$rootScope.urlStack.length);

                self.$rootScope.urlStack.slice(self.$rootScope.urlStack.length - depth, depth).forEach(function (urlObj) {
                    delete self.$rootScope.urlParams[urlObj.location];
                });

                self.$rootScope.urlStack.splice(self.$rootScope.urlStack.length - depth, depth);
            }
            urlService.prototype.route = function (location, skipUrlTrack, urlParams) {
                this.$rootScope.step = location;
                this.$rootScope.urlParams = this.$rootScope.urlParams || {};
                urlParams = urlParams || {};
                if (urlParams !== this.$rootScope.urlParams[location])
                    this.$rootScope.urlParams[location] = _.clone(urlParams);
                if (needGoBack && (skipUrlTrack == null || !skipUrlTrack)) {
                    var locationAlreadyExists = false;

                    if (this.$rootScope.urlStack.length) {
                        var urlObj = this.$rootScope.urlStack[this.$rootScope.urlStack.length - 1];
                        locationAlreadyExists = urlObj.location === location;
                    }

                    !locationAlreadyExists && this.$rootScope.urlStack.push({fn: arguments.callee, location: location});
                }

                this.$location.path(location);
            }
            urlService.prototype.addLocation = function (location) {
                var self = this,
                    arr;

                if (location) {
                    if (toString.call(location) == '[object Array]') {
                        arr = location;
                    } else if (typeof location === 'string') {
                        arr = [location];
                    }
                    arr = _.difference(arr, self.locations);
                    self.locations = Array.prototype.concat.apply(self.locations, arr);

                    arr.forEach(function (loc) {
                        self[loc] = self[loc] || function () {
                                var args = Array.prototype.slice.apply(arguments);
                                args.splice(0, 0, loc);
                                urlService.prototype.route.apply(self, args);
                            }
                    });
                }
            }
            urlService.prototype.firstPage = function () {
                this.locations.length && this[this.locations[0]]();
            }

            appModule.
                config(["$provide", function ($provide) {
                    $provide.service('urlService', urlService);
                }]).
                config(["$routeProvider", function ($routeProvider) {
                    locations && locations.forEach(function (loc) {
                        $routeProvider.when("/" + loc, {templateUrl: loc + ".html"});
                    });
                    return $routeProvider.otherwise({redirectTo: "/"});
                }]);
        }
    });