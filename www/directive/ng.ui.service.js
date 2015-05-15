define(
    ["angular", "jquery", "underscore", "ng.ui.util"],
    function () {
        var Service = function ($parse, $timeout, $q, $exceptionHandler, $compile, $rootScope, angularEventTypes, angularConstants, appService, uiUtilService) {
            this.$parse = $parse;
            this.$timeout = $timeout;
            this.$q = $q;
            this.$exceptionHandler = $exceptionHandler;
            this.$compile = $compile;
            this.$rootScope = $rootScope;
            this.angularEventTypes = angularEventTypes;
            this.angularConstants = angularConstants;
            this.appService = appService;
            this.uiUtilService = uiUtilService;

            _.extend($inject, _.pick(this, Service.$inject));
        };

        Service.$inject = ["$parse", "$timeout", "$q", "$exceptionHandler", "$compile", "$rootScope", "angularEventTypes", "angularConstants", "appService", "uiUtilService"];
        var $inject = {};

        //Define sketch widget class
        var Class = function () {
                var len = arguments.length;
                var P = arguments[0];
                var F = arguments[len - 1];

                var C = typeof F.initialize == "function" ?
                    F.initialize :
                    function () {
                        P.prototype.initialize.apply(this, arguments);
                    };

                if (len > 1) {
                    var newArgs = [].concat(
                        Array.prototype.slice.call(arguments).slice(1, len - 1), F);

                    var OF = function () {
                    };
                    OF.prototype = P.prototype;
                    C.prototype = new OF;

                    newArgs.forEach(function (o) {
                        if (typeof o === "function") {
                            o = o.prototype;
                        }
                        _.extend(C.prototype, o);
                    });
                } else {
                    C.prototype = F;
                }
                return C;
            },
            Project = Class({
                CLASS_NAME: "Project",
                MEMBERS: {
                    projectRecord: {},
                    xrefRecord: [],
                    artifactSpecs: [],
                    sketchWorks: {
                        pages: []
                    }
                },
                initialize: function (projectRecord) {
                    //Wrap operations in object, data come from persisted db object.

                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                    _.extend(this.projectRecord, projectRecord);
                },
                populate: function (projectRecord) {
                    this.xrefRecord.splice(0, this.xrefRecord.length);
                    this.artifactSpecs.splice(0, this.artifactSpecs.length);
                    this.sketchWorks.pages.splice(0, this.sketchWorks.pages.length);

                    this.projectRecord = projectRecord;
                },
                loadDependencies: function () {
                    var self = this;

                    if (self.projectRecord._id) {
                        self.xrefRecord.splice(0, self.xrefRecord.length);
                        self.artifactSpecs.splice(0, self.artifactSpecs.length);
                        return $inject.appService.getProjectDependency({projectId: self.projectRecord._id}).then(
                            function (result) {
                                if (result.data.result == "OK") {
                                    var arr = result.data.resultValue;
                                    arr.splice(0, 0, 0, 0);
                                    Array.prototype.splice.apply(self.xrefRecord, arr);

                                    //Load artifact spec
                                    var promiseArr = [];
                                    self.xrefRecord.forEach(function (xref) {
                                        xref.artifactList.forEach(function (a) {
                                            promiseArr.push(
                                                $inject.appService.loadRepoArtifact({
                                                    _id: a.artifactId,
                                                    name: a.name,
                                                    type: xref.type
                                                }, xref.libraryId, xref.libraryName, a.version)
                                            );
                                        });
                                    });

                                    return $inject.$q.all(promiseArr).then(
                                        function (result) {
                                            result.splice(0, 0, 0, 0);
                                            Array.prototype.splice.apply(self.artifactSpecs, result);

                                            return $inject.uiUtilService.getResolveDefer();
                                        },
                                        function (err) {
                                            return $inject.uiUtilService.getRejectDefer(err);
                                        }
                                    );
                                } else {
                                    return $inject.uiUtilService.getRejectDefer(result.data.reason);
                                }
                            },
                            function (err) {
                                return $inject.uiUtilService.getRejectDefer(err);
                            }
                        );
                    } else {
                        return $inject.uiUtilService.getRejectDefer();
                    }
                },
                addLibrary: function (libraryId, libraryName, type, artifactList) {
                    artifactList = artifactList || [];

                    var xref = _.findWhere(this.xrefRecord, {libraryId: libraryId});
                    if (xref) {
                        var arr = _.filter(xref.artifactList, function (a) {
                            return a.refCount > 0;
                        });
                        artifactList = _.reject(artifactList, function (a) {
                            return _.findWhere(arr, {artifactId: a.artifactId});
                        })
                        if (artifactList.length) {
                            artifactList.splice(0, 0, arr.length, 0);
                            Array.prototype.splice.apply(arr, artifactList);
                        }
                        xref.artifactList.splice(0, xref.artifactList.length);
                        if (arr.length) {
                            arr.splice(0, 0, 0, 0);
                            Array.prototype.splice.apply(xref.artifactList, arr);
                        }
                    } else {
                        xref = {
                            projectId: this.projectRecord._id,
                            libraryId: libraryId,
                            libraryName: libraryName,
                            type: type,
                            artifactList: artifactList
                        };
                        this.xrefRecord.push(xref);
                    }

                    return xref;
                },
                removeLibrary: function (libraryId) {
                    var index;
                    this.xrefRecord.every(function (xref, i) {
                        if (xref.libraryId == libraryId) {
                            if (!_.find(xref.artifactList, function (a) {
                                    return a.refCount > 0;
                                })) {
                                index = i;
                            }

                            return false;
                        }

                        return true;
                    });
                    if (index != null) {
                        this.xrefRecord.splice(index, 1);
                        return true;
                    }

                    return false;
                },
                loadArtifact: function (libraryId, artifactId, version) {
                    var self = this,
                        loadedSpec = _.findWhere(self.artifactSpecs, {artifactId: artifactId, version: version});

                    if (loadedSpec) {
                        return $inject.uiUtilService.getResolveDefer(loadedSpec);
                    } else {
                        var xref = _.findWhere(self.xrefRecord, {libraryId: libraryId}),
                            artifact;

                        if (xref && !xref.artifactList.every(function (a) {
                                if (a.artifactId === artifactId && a.version === version) {
                                    artifact = a;
                                    return false;
                                }

                                return true;
                            })) {
                            return $inject.appService.loadRepoArtifact({
                                _id: artifactId,
                                name: artifact.name,
                                type: xref.type
                            }, xref.libraryId, xref.libraryName, version).then(
                                function (loadedSpec) {
                                    return $inject.uiUtilService.getResolveDefer(loadedSpec);
                                },
                                function (err) {
                                    return $inject.uiUtilService.getRejectDefer(err);
                                }
                            );
                        } else {
                            return $inject.uiUtilService.getRejectDefer();
                        }
                    }
                },
                refArtifact: function (libraryId, artifactId, name, version) {
                    var self = this;

                    if (self.projectRecord._id) {
                        var xref = _.findWhere(this.xrefRecord, {libraryId: libraryId});
                        if (xref) {
                            if (xref.artifactList.every(function (a) {
                                    if (a.artifactId == artifactId) {
                                        if (a.version == version) {
                                            a.refCount = (a.refCount || 0) + 1;
                                        }
                                        return false;
                                    }
                                    return true;
                                })) {
                                xref.artifactList.push({
                                    artifactId: artifactId,
                                    name: name,
                                    version: version,
                                    refCount: 1
                                });
                            }
                        }
                    }
                },
                unrefArtifact: function (artifactId) {
                    var self = this;

                    if (self.projectRecord._id) {
                        var xrefIndex;

                        this.xrefRecord.every(function (xref, i) {
                            var index, found;

                            found = !xref.artifactList.every(function (a, j) {
                                if (a.artifactId == artifactId) {
                                    if (a.refCount) {
                                        a.refCount--;
                                        index = j;
                                    }
                                    return false;
                                }
                                return true;
                            });

                            if (index != null) {
                                xref.artifactList.splice(index, 1);
                                if (!xref.artifactList.length)
                                    xrefIndex = i;
                            }

                            return !found;
                        });

                        if (xrefIndex != null) {
                            self.xrefRecord.splice(xrefIndex, 1);
                        }
                    }
                },
                selectArtifact: function (libraryId, artifactId, name, version) {
                    var self = this;

                    if (self.projectRecord._id) {
                        var xref = _.findWhere(this.xrefRecord, {libraryId: libraryId});
                        if (xref) {
                            if (xref.artifactList.every(function (a) {
                                    if (a.artifactId == artifactId) {
                                        return false;
                                    }
                                    return true;
                                })) {
                                xref.artifactList.push({
                                    artifactId: artifactId,
                                    name: name,
                                    version: version
                                });
                            }

                            return true;
                        }
                    }

                    return false;
                },
                unselectArtifact: function (libraryId, artifactId) {
                    var self = this,
                        result = {libraryUnselect: false, artifactUnselect: false};

                    if (self.projectRecord._id) {
                        var xrefIndex;

                        if (!self.xrefRecord.every(function (record, i) {
                                if (record.libraryId === libraryId) {
                                    xrefIndex = i;

                                    return false;
                                }

                                return true;
                            })) {
                            var xref = self.xrefRecord[xrefIndex],
                                index;

                            xref.artifactList.every(function (a, i) {
                                if (a.artifactId == artifactId) {
                                    if (!a.refCount) {
                                        index = i;
                                    }
                                    return false;
                                }
                                return true;
                            });

                            if (index != null) {
                                xref.artifactList.splice(index, 1);
                                result.artifactUnselect = true;

                                if (!xref.artifactList.length) {
                                    result.libraryUnselect = true;
                                    self.xrefRecord.splice(xrefIndex, 1);
                                }
                            }
                        }
                    }

                    return result;
                },
                tryLock: function (userId) {
                    var self = this;

                    if (self.projectRecord._id && !self.projectRecord.lock) {
                        return $inject.appService.lockProject(userId, self.projectRecord._id).then(
                            function () {
                                self.projectRecord.lock = true;

                                return $inject.uiUtilService.getResolveDefer(self);
                            },
                            function (err) {
                                return $inject.uiUtilService.getResolveDefer(self);
                            }
                        );
                    } else {
                        return $inject.uiUtilService.getResolveDefer(self);
                    }
                },
                unlock: function (userId) {
                    var self = this;

                    if (self.projectRecord._id && self.projectRecord.lock) {
                        return $inject.appService.unlockProject(userId, self.projectRecord._id).then(
                            function () {
                                self.projectRecord.lock = false;

                                return $inject.uiUtilService.getResolveDefer(self);
                            },
                            function (err) {
                                return $inject.uiUtilService.getResolveDefer(self);
                            }
                        );
                    } else {
                        return $inject.uiUtilService.getResolveDefer(self);
                    }
                },
                load: function () {
                    var self = this;

                    if (self.projectRecord._id) {
                        return $inject.$q.all([
                            $inject.appService.getProject({_id: self.projectRecord._id}),
                            self.loadDependencies(),
                            self.loadSketch()
                        ]).then(function (result) {
                            if (result[0].data.result === "OK") {
                                var arr = result[0].data.resultValue;

                                arr.length && _.extend(self.projectRecord, arr[0]);

                                return $inject.uiUtilService.getResolveDefer(self);
                            } else {
                                return $inject.uiUtilService.getRejectDefer(result[0].data.reason);
                            }
                        }, function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        });
                    } else {
                        return $inject.uiUtilService.getResolveDefer(self);
                    }
                },
                unload: function () {
                    var self = this;

                    if (self.projectRecord._id) {
                        $("head link[type='text/css'][projectId='{0}']".format(self.projectRecord._id)).remove();

                        self.sketchWorks.pages.forEach(function (pageObj) {
                            pageObj.remove();
                        });
                    }
                },
                save: function () {
                    var self = this;

                    if (self.projectRecord._id) {
                        return self.saveSketch().then(function () {
                            var promiseArr = [];
                            self.xrefRecord.forEach(
                                function (xref) {
                                    promiseArr.push($inject.appService.updateProjectDependency(self.projectRecord._id, xref.libraryId, xref.artifactList));
                                }
                            );

                            return promiseArr.length && $inject.$q.all(promiseArr) || $inject.uiUtilService.getResolveDefer();
                        }, function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        });
                    }

                    return $inject.uiUtilService.getRejectDefer(err);
                },
                loadSketch: function () {
                    var self = this;

                    if (self.projectRecord._id) {
                        self.sketchWorks.pages.splice(0, self.sketchWorks.pages.length);
                        return $inject.appService.loadSketch(self.projectRecord._id).then(function (pages) {
                            if (pages && pages.length) {
                                pages.forEach(function (pageObj) {
                                    var page = Service.prototype.fromObject(pageObj);
                                    page && self.sketchWorks.pages.push(page);
                                });
                            }

                            return $inject.uiUtilService.getResolveDefer(self);
                        }, function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        });
                    } else {
                        return $inject.uiUtilService.getResolveDefer(self);
                    }
                },
                saveSketch: function () {
                    var self = this;

                    if (self.projectRecord._id && self.sketchWorks.pages.length) {
                        return $inject.appService.saveSketch(self.projectRecord._id, self.sketchWorks);
                    } else {
                        return $inject.uiUtilService.getResolveDefer();
                    }
                },
                convertToHtml: function (userId) {
                    var self = this;

                    if (self.projectRecord._id && self.projectRecord.lock) {
                        return $inject.appService.convertToHtml(userId, self.projectRecord._id);
                    } else {
                        return $inject.uiUtilService.getResolveDefer();
                    }
                }
            }),
            State = Class({
                CLASS_NAME: "State",
                MEMBERS: {
                    id: "",
                    context: null,
                    node: null,
                    name: null,
                    transitions: []
                },
                initialize: function (node, name, context, id) {
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                    if (typeof node === "string") {
                        this.node = node;
                    } else {
                        this.widgetObj = node;
                        this.node = node.id;
                    }
                    this.context = context;
                    this.name = name;
                    this.id = id || "State_" + new Date().getTime();
                },
                toJSON: function () {
                    return _.extend(_.pick(this, ["id", "node", "name"], "CLASS_NAME"), {
                        transitions: $inject.uiUtilService.arrayOmit(this.transitions, "$$hashKey"),
                        context: this.context && this.context.node !== "?" && this.context.id || ""
                    });
                },
                fromObject: function (obj) {
                    var ret = new State(obj.node, obj.name, obj.context, obj.id);
                    obj.transitions && obj.transitions.forEach(function (t) {
                        var transition = Transition.prototype.fromObject(t);
                        transition.state = ret;
                        ret.transitions.push(transition);
                    });

                    return ret;
                },
                setContext: function (value) {
                    this.context = value;
                },
                toString: function () {
                    return this.node !== "?" && this.id || "?";
                },
                addTransition: function (name) {
                    this.transitions.push(new Transition(name, this));
                },
                removeToState: function (toState) {
                    var self = this;

                    self.transitions = _.reject(self.transitions, function (t) {
                        return t.toState == toState;
                    });
                },
                removeToStateOption: function (stateOption) {
                    var self = this;

                    self.transitions = _.reject(self.transitions, function (t) {
                        return t.toState.name == stateOption.name;
                    });
                },
                clone: function (widgetObj) {
                    var cloneObj = new State(widgetObj, this.name, this.context);

                    return cloneObj;
                }
            }),
            Transition = Class({
                CLASS_NAME: "Transition",
                MEMBERS: {
                    id: "",
                    name: "",
                    state: null,
                    trigger: null,
                    actionObj: null
                },
                initialize: function (name, state, id) {
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.name = name;
                    this.state = state;
                    this.id = id || "Transition_" + new Date().getTime();
                    this.actionObj = new SequenceTransitionAction();

                    if (state != null && typeof state === "object") {
                        this.actionObj.setWidget(state.widgetObj);
                    }
                },
                toJSON: function () {
                    return _.extend(_.pick(this, ["name", "id", "trigger", "actionObj"], "CLASS_NAME"), {
                        state: this.state.id
                    });
                },
                clone: function () {
                    var cloneObj = new Transition(this.name, this.state);
                    cloneObj.actionObj = this.actionObj.clone();

                    return cloneObj;
                },
                fromObject: function (obj) {
                    var ret = new Transition(obj.name, null, obj.id);

                    if (obj.trigger) {
                        ret.setTrigger(obj.trigger.id, obj.trigger.triggerType, obj.trigger.eventName, obj.trigger.options);
                        ret[obj.trigger.triggerType.charAt(0).toLowerCase() + obj.trigger.triggerType.substr(1) + "EventName"] = obj.trigger.id;
                    }

                    if (obj.actionObj) {
                        var classes = ["SequenceTransitionAction"],
                            className = obj.actionObj.CLASS_NAME,
                            actionObj;

                        classes.every(function (clazz) {
                            if (eval("className === {0}.prototype.CLASS_NAME".format(clazz))) {
                                actionObj = eval("{0}.prototype.fromObject(obj.actionObj)".format(clazz));
                                return false;
                            }

                            return true;
                        });
                        ret.actionObj = actionObj;
                    }

                    return ret;
                },
                setAction: function (actionObj) {
                    this.actionObj = actionObj;
                },
                setTrigger: function (id, triggerType, eventName, options) {
                    var self = this,
                        trigger;

                    function triggerCallback() {
                        function doActionHandler() {
                            if (self.actionObj) {
                                return self.actionObj.doAction();
                            } else {
                                return $inject.uiUtilService.getResolveDefer();
                            }
                        }

                        doActionHandler.onceId = "Transition.setTrigger.triggerCallback.doActionHandler";

                        return $inject.uiUtilService.once(doActionHandler, null, $inject.angularConstants.unresponsiveInterval)();
                    }

                    if (triggerType === "Gesture") {
                        if (eventName) {
                            trigger = new GestureTrigger(id, eventName, options, triggerCallback);
                        }
                    }

                    if (trigger) {
                        if (this.trigger) {
                            this.unregisterTrigger();
                        }
                        this.trigger = trigger;
                    }
                },
                registerTrigger: function (widgetObj) {
                    this.trigger && widgetObj.isPlaying && this.trigger.on(widgetObj);
                },
                unregisterTrigger: function () {
                    this.trigger && this.trigger.off();
                }
            }),
            BaseTransitionAction = Class({
                CLASS_NAME: "BaseTransitionAction",
                MEMBERS: {
                    id: "",
                    actionType: "",
                    widgetObj: null
                },
                initialize: function (widgetObj, actionType, id) {
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.widgetObj = widgetObj;
                    this.actionType = actionType;
                    this.id = id || "TransitionAction_" + new Date().getTime();
                },
                toJSON: function () {
                    return _.extend(_.pick(this, ["id", "actionType"], "CLASS_NAME"), {
                        widgetObj: this.widgetObj.id
                    });
                },
                fromObject: function (obj) {
                    var self = this;

                    BaseSketchWidgetClass.prototype.matchReference(obj.widgetObj, function (result) {
                        self.setWidget(result);
                    });
                },
                clone: function (cloneObj, MEMBERS) {
                    var self = this;

                    _.extend(MEMBERS = MEMBERS || {}, BaseTransitionAction.prototype.MEMBERS);
                    MEMBERS = _.omit(MEMBERS, ["id", "actionType", "widgetObj"]);
                    _.keys(MEMBERS).forEach(function (member) {
                        cloneObj[member] = angular.copy(self[member]);
                    });

                    return cloneObj;
                },
                doAction: function () {
                },
                restoreWidget: function (widgetObj) {
                },
                setWidget: function (widgetObj) {
                    this.widgetObj = widgetObj;
                }
            }),
            SequenceTransitionAction = Class(BaseTransitionAction, {
                CLASS_NAME: "SequenceTransitionAction",
                MEMBERS: {
                    childActions: []
                },
                initialize: function (widgetObj, id) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [widgetObj, "Sequence", id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                },
                toJSON: function () {
                    var jsonObj = SequenceTransitionAction.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME"]), {childActions: $inject.uiUtilService.arrayOmit(this.childActions, "$$hashKey")});

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new SequenceTransitionAction(null, obj.id);

                    SequenceTransitionAction.prototype.__proto__.fromObject.apply(ret, [obj]);

                    var classes = ["EffectTransitionAction", "StateTransitionAction", "ConfigurationTransitionAction"];
                    obj.childActions && obj.childActions.forEach(function (action) {
                        var className = action.CLASS_NAME,
                            actionObj;

                        classes.every(function (clazz) {
                            if (eval("className === {0}.prototype.CLASS_NAME".format(clazz))) {
                                actionObj = eval("{0}.prototype.fromObject(action)".format(clazz));
                                ret.childActions.push(actionObj);
                                return false;
                            }

                            return true;
                        });
                    });

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    var self = this;

                    cloneObj = cloneObj || new SequenceTransitionAction(this.widgetObj);

                    _.extend(MEMBERS = MEMBERS || {}, SequenceTransitionAction.prototype.MEMBERS);
                    MEMBERS = _.omit(MEMBERS, ["childActions"]);

                    SequenceTransitionAction.prototype.__proto__.clone.apply(self, [cloneObj, MEMBERS]);

                    this.childActions.forEach(function (child) {
                        cloneObj.childActions.push(child.clone());
                    });

                    return cloneObj;
                },
                doAction: function () {
                    var self = this,
                        arr = [],
                        chainId = "SequenceTransitionAction.doAction." + self.id;

                    self.childActions.forEach(function (actionObj) {
                        arr.push(function () {
                            return actionObj.doAction();
                        });
                    });

                    return $inject.uiUtilService.chain(arr,
                        chainId,
                        $inject.angularConstants.renderTimeout);
                },
                addAction: function (actionType) {
                    var action;

                    if (actionType === "Effect") {
                        action = new EffectTransitionAction(this.widgetObj);
                    } else if (actionType === "State") {
                        action = new StateTransitionAction(this.widgetObj, this.widgetObj.initialStateOption.name);
                    } else if (actionType === "Configuration") {
                        action = new ConfigurationTransitionAction(this.widgetObj);
                    }

                    action && this.childActions.push(action);
                }
            }),
            EffectTransitionAction = Class(BaseTransitionAction, {
                CLASS_NAME: "EffectTransitionAction",
                MEMBERS: {
                    artifactSpec: {},
                    effect: {}
                },
                initialize: function (widgetObj, artifactSpec, effect, id) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [widgetObj, "Effect", id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                    this.artifactSpec = artifactSpec || this.artifactSpec;
                    this.effect = effect || this.effect;
                },
                toJSON: function () {
                    var jsonObj = EffectTransitionAction.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["artifactSpec", "effect", "CLASS_NAME"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new EffectTransitionAction(null, obj.artifactSpec, obj.effect, obj.id);

                    EffectTransitionAction.prototype.__proto__.fromObject.apply(ret, [obj]);

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new EffectTransitionAction(this.widgetObj, this.artifactSpec, this.effect);

                    _.extend(MEMBERS = MEMBERS || {}, EffectTransitionAction.prototype.MEMBERS);

                    EffectTransitionAction.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                doAction: function () {
                    var self = this,
                        defer = $inject.$q.defer();

                    if (self.widgetObj.$element && self.widgetObj.$element[0].nodeType == 1 && self.widgetObj.$element.parent().length) {
                        var fullName = self.artifactSpec.directiveName;
                        if (self.artifactSpec.version) {
                            fullName = fullName + "-" + self.artifactSpec.version.replace(/\./g, "-")
                        }
                        self.widgetObj.$element.attr(fullName, "");
                        self.widgetObj.$element.attr("effect", self.effect.name);

                        if (self.effect.type === "Animation") {
                            self.cssAnimation = {};

                            if (self.effect.options.duration) {
                                _.extend(
                                    self.cssAnimation, $inject.uiUtilService.prefixedStyle("animation-duration", "{0}s", self.effect.options.duration)
                                );
                            }
                            if (self.effect.options.timing) {
                                _.extend(
                                    self.cssAnimation, $inject.uiUtilService.prefixedStyle("timing-function", "{0}", self.effect.options.timing)
                                );
                            }

                            self.widgetObj.$element.css(self.cssAnimation);

                            $inject.uiUtilService.onAnimationEnd(self.widgetObj.$element).then(function () {
                                self.restoreWidget();
                                defer.resolve(self);
                            });

                            return defer.promise;
                        }
                    }

                    $inject.$timeout(function () {
                        defer.resolve(self);
                    });

                    return defer.promise;
                },
                restoreWidget: function () {
                    var self = this;

                    if (self.widgetObj.$element && self.widgetObj.$element[0].nodeType == 1 && self.widgetObj.$element.parent().length) {
                        var fullName = self.artifactSpec.directiveName + "-" + self.artifactSpec.version.replace(/\./g, "-");
                        self.widgetObj.$element.removeAttr(fullName);
                        self.widgetObj.$element.removeAttr("effect");

                        if (self.effect.type === "Animation") {
                            for (var key in self.cssAnimation) {
                                self.widgetObj.$element.css(key, "");
                            }
                            self.cssAnimation = null;
                        }
                    }
                }
            }),
            StateTransitionAction = Class(BaseTransitionAction, {
                CLASS_NAME: "StateTransitionAction",
                MEMBERS: {
                    newState: ""
                },
                initialize: function (widgetObj, newState, id) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [widgetObj, "State", id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                    this.newState = newState || this.newState;
                },
                toJSON: function () {
                    var jsonObj = StateTransitionAction.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["newState", "CLASS_NAME"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new StateTransitionAction(null, obj.newState, obj.id);

                    StateTransitionAction.prototype.__proto__.fromObject.apply(ret, [obj]);

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new StateTransitionAction(this.widgetObj, this.newState);

                    _.extend(MEMBERS = MEMBERS || {}, StateTransitionAction.prototype.MEMBERS);

                    StateTransitionAction.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                doAction: function () {
                    var self = this,
                        defer = $inject.$q.defer();

                    $inject.$timeout(function () {
                        self.widgetObj.setState(self.newState);

                        if (self.widgetObj.$element && self.widgetObj.$element[0].nodeType == 1 && self.widgetObj.$element.parent().length) {
                            var animationName = self.widgetObj.$element.css("animation-name");
                            if (animationName && animationName !== "none") {
                                $inject.uiUtilService.onAnimationEnd(self.widgetObj.$element).then(function () {
                                    defer.resolve(self);
                                });
                            }
                        }
                        defer.resolve(self);
                    });

                    return defer.promise;
                }
            }),
            ConfigurationTransitionAction = Class(BaseTransitionAction, {
                CLASS_NAME: "ConfigurationTransitionAction",
                MEMBERS: {
                    configuration: []
                },
                initialize: function (widgetObj, configuration, id) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [widgetObj, "Configuration", id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }
                    if (configuration) {
                        this.configuration = configuration;
                    } else if (widgetObj && widgetObj.widgetSpec) {
                        this.setWidget(widgetObj);
                    }
                },
                toJSON: function () {
                    var jsonObj = ConfigurationTransitionAction.prototype.__proto__.toJSON.apply(this);

                    var configuration = $inject.uiUtilService.arrayOmit(this.configuration, ["$$hashKey", "widget"]),
                        arr = [];
                    configuration.forEach(function (configurationItem) {
                        if (configurationItem.pickedValue != null) {
                            var config = {key: configurationItem.key};

                            if (configurationItem.type === "boundWriteList") {
                                config.pickedValue = $inject.uiUtilService.arrayOmit(configurationItem.pickedValue, "$$hashKey");
                            } else {
                                config.pickedValue = configurationItem.pickedValue;
                            }

                            arr.push(config);
                        }
                    });

                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME"]), {configuration: arr});

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new ConfigurationTransitionAction(null, obj.configuration, obj.id);

                    ConfigurationTransitionAction.prototype.__proto__.fromObject.apply(ret, [obj]);

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new ConfigurationTransitionAction(this.widgetObj, this.configuration);

                    _.extend(MEMBERS = MEMBERS || {}, ConfigurationTransitionAction.prototype.MEMBERS);

                    ConfigurationTransitionAction.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                doAction: function () {
                    var self = this,
                        defer = $inject.$q.defer();

                    $inject.$timeout(function () {
                        var configuration = _.filter(self.configuration, function (item) {
                            return item.pickedValue != null;
                        });

                        if (configuration.length) {
                            var obj = {};
                            configuration.forEach(function (configurationItem) {
                                if (configurationItem.pickedValue != null) {
                                    obj[configurationItem.key] = {};
                                    obj[configurationItem.key].type = configurationItem.type;
                                    obj[configurationItem.key].defaultValue = configurationItem.defaultValue;
                                    obj[configurationItem.key].pickedValue = configurationItem.pickedValue;
                                }
                            });

                            self.widgetObj.setScopedValue && self.widgetObj.setScopedValue(obj);

                            if (self.widgetObj.$element && self.widgetObj.$element[0].nodeType == 1 && self.widgetObj.$element.parent().length) {
                                var animationName = self.widgetObj.$element.css("animation-name");
                                if (animationName && animationName !== "none") {
                                    $inject.uiUtilService.onAnimationEnd(self.widgetObj.$element).then(function () {
                                        defer.resolve(self);
                                    });
                                }
                            }
                        }
                        defer.resolve(self);
                    });

                    return defer.promise;
                },
                setWidget: function (widgetObj) {
                    var self = this;

                    if (self.widgetObj && widgetObj.id !== self.widgetObj.id) {
                        self.configuration.splice(0, self.configuration.length);
                    }

                    ConfigurationTransitionAction.prototype.__proto__.setWidget.apply(self, [widgetObj]);

                    self.readWidgetSpec();
                },
                readWidgetSpec: function () {
                    var self = this;

                    if (self.widgetObj.widgetSpec) {
                        _.each(_.omit(self.widgetObj.widgetSpec.configuration, "state", "handDownConfiguration"), function (value, key) {
                            var configurationItem = self.getConfigurationItem(key),
                                pickedValue = configurationItem && configurationItem.pickedValue || null,
                                obj = configurationItem || {key: key};

                            _.extend(obj, value, {
                                configuredValue: pickedValue || value.pickedValue || value.defaultValue
                            });

                            if (obj.type !== "boundWriteList") {
                                if (obj.type === "boundReadList") {
                                    obj.options = self.widgetObj.getConfiguration(obj.listName);
                                }
                                obj.pickedValue = pickedValue;

                                !configurationItem && self.configuration.push(obj);
                            }
                        });
                    }

                    self.configuration && self.configuration.forEach(function (configurationItem) {
                        configurationItem.widget = self.widgetObj;
                    });
                },
                getConfigurationItem: function (key) {
                    var result = null;

                    this.configuration && this.configuration.every(function (configurationItem) {
                        if (configurationItem.key === key) {
                            result = configurationItem;
                            return false;
                        }

                        return true;
                    });

                    return result;
                },
                setConfigurationItem: function (item) {
                    this.configuration && this.configuration.every(function (configurationItem) {
                        if (configurationItem.key === item.key) {
                            configurationItem.pickedValue = item.configuredValue;
                            return false;
                        }

                        return true;
                    });
                }
            }),
            BaseTrigger = Class({
                CLASS_NAME: "BaseTrigger",
                MEMBERS: {
                    id: "",
                    triggerType: "",
                    eventName: "",
                    options: null,
                    widgetObj: null
                },
                initialize: function (id, triggerType, eventName, options) {
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.id = id;
                    this.triggerType = triggerType;
                    this.eventName = eventName;
                    this.options = options;
                },
                toJSON: function () {
                    return _.extend(_.pick(this, ["id", "triggerType", "eventName", "options", "CLASS_NAME"]));
                },
                fromObject: function (obj) {
                },
                clone: function (cloneObj, MEMBERS) {
                    var self = this;

                    _.extend(MEMBERS = MEMBERS || {}, BaseTrigger.prototype.MEMBERS);
                    MEMBERS = _.omit(MEMBERS, ["id", "triggerType", "eventName", "widgetObj"]);
                    _.keys(MEMBERS).forEach(function (member) {
                        cloneObj[member] = angular.copy(self[member]);
                    });

                    return cloneObj;
                },
                on: function (widgetObj) {
                    this.widgetObj = widgetObj;
                },
                off: function () {
                }
            }),
            GestureTrigger = Class(BaseTrigger, {
                CLASS_NAME: "GestureTrigger",
                MEMBERS: {},
                initialize: function (id, eventName, options, callback) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [id, "Gesture", eventName, _.clone(options)]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.callback = callback;
                },
                toJSON: function () {
                    var jsonObj = GestureTrigger.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new GestureTrigger(obj.id, obj.eventName, obj.options);

                    GestureTrigger.prototype.__proto__.fromObject.apply(ret, [obj]);

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    var self = this;

                    cloneObj = cloneObj || new GestureTrigger(null, self.eventName, self.options);
                    _.extend(MEMBERS = MEMBERS || {}, GestureTrigger.prototype.MEMBERS);

                    GestureTrigger.prototype.__proto__.clone.apply(self, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                on: function (widgetObj) {
                    var self = this;

                    if (widgetObj && widgetObj.$element && widgetObj.$element[0].nodeType == 1 && widgetObj.$element.parent().length && self.eventName) {
                        self.initialize.prototype.__proto__.on.apply(self, [widgetObj]);

                        var mc = widgetObj.$element.data("gesture-hammer");
                        if (!mc) {
                            mc = new Hammer.Manager(widgetObj.$element[0]);
                            widgetObj.$element.data("gesture-hammer", mc);
                        }

                        switch (self.eventName) {
                            case "panleft":
                            case "panright":
                            case "panup":
                            case "pandown":
                                mc.add(new Hammer.Pan(_.clone(self.options)));
                            case "touch":
                                mc.add(new Hammer.Tap(_.clone(self.options)));
                                break;
                            case "press":
                                mc.add(new Hammer.Press(_.clone(self.options)));
                                break;
                            case "pinchin":
                            case "pinchout":
                                mc.add(new Hammer.Pinch(_.clone(self.options)));
                                break;
                            case "tap":
                            case "doubletap":
                                mc.add(new Hammer.Tap(_.clone(self.options)));
                                break;
                            case "swipe":
                                mc.add(new Hammer.Swipe(_.clone(self.options)));
                                break;
                        }
                        mc.on(self.eventName, function (event) {
                            if (event && event.srcEvent) {
                                event.srcEvent.stopPropagation && event.srcEvent.stopPropagation();
                            }

                            self.callback && widgetObj.handleEvent(self.callback)();
                        });

                        self.hammer = mc;
                        self.recognizer = self.hammer.get(self.eventName);
                    }
                },
                off: function () {
                    this.initialize.prototype.__proto__.off.apply(this, []);

                    if (this.hammer) {
                        this.hammer.off(this.eventName);
                        this.hammer.remove(this.recognizer);
                        $(this.hammer.element).removeData("gesture-hammer");
                        this.hammer.destroy();
                        this.hammer = null;
                    }
                }
            }),
            StyleManager = Class({
                CLASS_NAME: "StyleManager",
                MEMBERS: {
                    widgetObj: null,
                    stateMaps: {},
                    omniClasses: [] //Classes irrelevant to widget state
                },
                initialize: function (widgetObj) {
                    //TODO How to group each element's style into a css class

                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.widgetObj = widgetObj;
                },
                toJSON: function () {
                    var self = this,
                        stateMaps = {};

                    _.each(self.stateMaps, function (stateMap, stateContext) {
                        var value = (stateMaps[stateContext] = {});

                        _.each(stateMap, function (stateValue, state) {
                            value[state] = _.pick(stateValue, ["style", "beforeStyle", "afterStyle"]);
                            value[state].styleSource = [];
                            stateValue.styleSource.forEach(function (source) {
                                if (!_.isEmpty(source.style) || !_.isEmpty(source.beforeStyle) || !_.isEmpty(source.afterStyle)) {
                                    value[state].styleSource.push(source);
                                }
                            });
                        });
                    });

                    return _.extend(_.pick(this, "CLASS_NAME"), {omniClasses: _.without(this.omniClasses, $inject.angularConstants.widgetClasses.activeClass)}, {stateMaps: stateMaps});
                },
                fromObject: function (obj) {
                    var ret = new StyleManager();
                    ret.stateMaps = obj.stateMaps;
                    ret.omniClasses = obj.omniClasses;

                    return ret;
                },
                addOmniClass: function (classes) {
                    var self = this;

                    if (classes) {
                        var newClassList = _.difference(_.uniq(classes.split(" ")), self.omniClasses);

                        if (newClassList.length) {
                            newClassList.forEach(function (c) {
                                self.omniClasses.splice(self.omniClasses.length, 0, c);
                            });

                            self.widgetObj.$element && self.widgetObj.$element.addClass(self.omniClasses.join(" "));
                        }
                    }

                    return self;
                },
                removeOmniClass: function (classes) {
                    var self = this;

                    if (classes) {
                        var removeClassList = _.uniq(classes.split(" "));

                        if (removeClassList.length) {
                            removeClassList.forEach(function (removeClazz) {
                                var index;
                                if (!self.omniClasses.every(function (c, i) {
                                        if (c == removeClazz) {
                                            index = i;
                                            return false;
                                        }
                                        return true;
                                    })) {
                                    self.omniClasses.splice(index, 1);
                                }
                            });

                            self.widgetObj.$element && self.widgetObj.$element.removeClass(removeClassList.join(" "));
                        }
                    }
                },
                addClass: function (classes, state, stateContext) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            },
                        classList = stateValue.classList;

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    if (classes) {
                        var newClassList = _.difference(_.uniq(classes.split(" ")), classList);

                        if (newClassList.length) {
                            newClassList.forEach(function (c) {
                                classList.splice(classList.length, 0, c);
                            });

                            if (state == self.widgetObj.state) {
                                self.widgetObj.$element && self.widgetObj.$element.addClass(classList.join(" "));
                            }
                        }
                    }

                    return self;
                },
                removeClass: function (classes, state, stateContext) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            };

                    if (stateMap === self.stateMaps[stateContext] && stateValue === stateMap[state.name]) {
                        var classList = stateValue.classList;

                        if (classes && classList.length) {
                            var removeClassList = _.uniq(classes.split(" "));

                            if (removeClassList.length) {
                                removeClassList.forEach(function (removeClazz) {
                                    var index;
                                    if (!classList.every(function (c, i) {
                                            if (c == removeClazz) {
                                                index = i;
                                                return false;
                                            }
                                            return true;
                                        })) {
                                        classList.splice(index, 1);
                                    }
                                });

                                if (state == self.widgetObj.state) {
                                    self.widgetObj.$element && self.widgetObj.$element.removeClass(removeClassList.join(" "));
                                }
                            }
                        }
                    }

                    return self;
                },
                hasClass: function (clazz, state, stateContext) {
                    var self = this,
                        classList = self.classList(state, stateContext);

                    return !classList.every(function (c) {
                        return c != clazz;
                    });
                },
                classList: function (state, stateContext) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            };

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    return _.union(stateValue.classList, self.omniClasses);
                },
                css: function (state, stateContext) {
                    var args = Array.prototype.slice.call(arguments);
                    args.splice(2, 0, "");
                    return this.pseudoCss.apply(this, args);
                },
                pseudoCss: function (state, stateContext, pseudo) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            },
                        args = Array.prototype.slice.call(arguments, 2),
                        ret = self.widgetObj,
                        stylePseudoPrefix = ((pseudo || "") + "Style").replace(/^:(.+)/, "$1");
                    stylePseudoPrefix = stylePseudoPrefix.charAt(0).toLowerCase() + stylePseudoPrefix.substr(1);

                    var style = stateValue[stylePseudoPrefix];

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    switch (args.length) {
                        case 0:
                            ret = _.pick(stateValue, ["style", "beforeStyle", "afterStyle"]);
                            break;
                        case 1:
                            ret = _.pick(stateValue, [stylePseudoPrefix]);
                            break;
                        case 2 :
                            if (typeof args[1] === "string")
                                ret = style[args[1]];
                            else if (typeof args[1] === "object") {
                                if (args[1]) {
                                    for (var key in args[1]) {
                                        self.pseudoCss(state, stateContext, pseudo, key, args[1][key]);
                                    }
                                } else {
                                    _.keys(style).forEach(function (key) {
                                        delete style[key];
                                    });
                                }
                            }
                            break;
                        case 3 :
                            if (typeof args[1] === "string") {
                                if (args[2] != null) {
                                    style[args[1]] = args[2];
                                } else {
                                    delete style[args[1]];
                                }
                                if (self.widgetObj.$element) {
                                    if (state == self.widgetObj.state) {
                                        if (stylePseudoPrefix === "style") {
                                            self.applyStyle(args[1], args[2]);
                                        } else {
                                            self.updatePseudoStyle(state, stateContext);
                                        }
                                    }
                                }
                            }
                            break;

                        default:
                            break;
                    }

                    return ret;
                },
                trackablePseudoCss: function (state, stateContext, source, pseudo) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            },
                        args = Array.prototype.slice.call(arguments, 3),
                        ret = self,
                        stylePseudoPrefix = ((pseudo || "") + "Style").replace(/^:(.+)/, "$1");
                    stylePseudoPrefix = stylePseudoPrefix.charAt(0).toLowerCase() + stylePseudoPrefix.substr(1);

                    var styleSource = _.findWhere(stateValue.styleSource, {source: source});
                    if (!styleSource) {
                        stateValue.styleSource.push(styleSource = {
                            source: source,
                            style: {},
                            beforeStyle: {},
                            afterStyle: {}
                        });
                    }
                    var sourceStyle = styleSource[stylePseudoPrefix];

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    switch (args.length) {
                        case 0:
                            ret = styleSource;
                            break;
                        case 1:
                            ret = sourceStyle;
                            break;
                        case 2 :
                            if (typeof args[1] === "string") {
                                ret = sourceStyle[args[1]];
                            } else if (typeof args[1] === "object") {
                                if (args[1]) {
                                    for (var key in args[1]) {
                                        self.trackablePseudoCss(state, stateContext, source, pseudo, key, args[1][key]);
                                    }
                                } else {
                                    var keys = _.keys(sourceStyle);

                                    if (keys.length) {
                                        keys.forEach(function (key) {
                                            delete sourceStyle[key];
                                            delete stateValue[stylePseudoPrefix][key];
                                        });

                                        //FIXME Use latestOnce
                                        var styleProps = {};
                                        styleProps[stylePseudoPrefix] = keys;
                                        self.uniteSourceStyle(state, stateContext, styleProps);
                                    }
                                }
                            }
                            break;
                        case 3 :
                            if (typeof args[1] === "string") {
                                if (args[2] != null) {
                                    sourceStyle[args[1]] = args[2];
                                } else {
                                    delete sourceStyle[args[1]];
                                    delete stateValue[stylePseudoPrefix][args[1]];
                                }
                                //FIXME Use latestOnce
                                var styleProps = {};
                                styleProps[stylePseudoPrefix] = [args[1]];
                                self.uniteSourceStyle(state, stateContext, styleProps);
                            }
                            break;

                        default:
                            break;
                    }

                    return ret;
                },
                uniteSourceStyle: function (state, stateContext, styleProps) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            };

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    _.each(styleProps, function (props, stylePseudoPrefix) {
                        var pseudoStyle = {},
                            pseudo = stylePseudoPrefix.replace(/style/i, "");
                        if (props && props.length) {
                            props.forEach(function (prop) {
                                var propValues = [];
                                _.pluck(stateValue.styleSource, stylePseudoPrefix).forEach(function (value) {
                                    if (value[prop] !== undefined) {
                                        propValues.push(value[prop]);
                                    }
                                });

                                pseudoStyle[prop] = propValues.length ? propValues[propValues.length - 1] : null;
                            });
                        } else {
                            _.pluck(stateValue.styleSource, stylePseudoPrefix).forEach(function (sourceStyle) {
                                _.extend(pseudoStyle, sourceStyle);
                            });
                        }
                        self.pseudoCss(state, stateContext, pseudo, pseudoStyle);
                    });
                },
                updatePseudoStyle: function (state, stateContext) {
                    var self = this;

                    function appendToPseudoEnabledWidgets() {
                        var defer = $inject.$q.defer();

                        var pseudoWidgets = _.clone($inject.$rootScope.visiblePseudoEnabledWidgets);
                        if ($inject.$rootScope.visiblePseudoEnabledWidgets.every(function (w) {
                                return w.id != self.widgetObj.id;
                            })) {
                            pseudoWidgets.push(self.widgetObj);
                        }

                        $inject.$timeout(function () {
                            $inject.$rootScope.visiblePseudoEnabledWidgets = pseudoWidgets;
                            defer.resolve();
                        });

                        return defer.promise;
                    }

                    appendToPseudoEnabledWidgets.onceId = "StyleManager.pseudoCss.appendToPseudoEnabledWidgets";

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            };

                    if (stateMap !== self.stateMaps[stateContext]) self.stateMaps[stateContext] = stateMap;
                    if (stateValue !== stateMap[state.name]) stateMap[state.name] = stateValue;

                    if (!_.isEmpty(stateValue.beforeStyle) || !_.isEmpty(stateValue.afterStyle)) {
                        $inject.uiUtilService.latestOnce(appendToPseudoEnabledWidgets, null, $inject.angularConstants.unresponsiveInterval)();
                    }
                },
                removePseudoStyle: function () {
                    var index;
                    $inject.$rootScope.visiblePseudoEnabledWidgets.every(function (w, i) {
                        if (w.id === self.id) {
                            index = i;
                            return false;
                        }

                        return true;
                    });

                    index != null && $inject.$rootScope.visiblePseudoEnabledWidgets.splice(index, 1);
                },
                applyStyle: function (styleName, styleValue) {
                    var self = this;

                    if (self.widgetObj.$element) {
                        var styleObj = $inject.uiUtilService.composeCssStyle(styleName, styleValue);
                        styleObj && _.each(styleObj, function (value, key) {
                            if (toString.call(value) === '[object Array]') {
                                value.forEach(function (v) {
                                    self.widgetObj.$element.css(key, v);
                                });
                            } else {
                                self.widgetObj.$element.css(key, value);
                            }
                        })
                    }
                },
                draw: function (state, stateContext) {
                    var self = this;

                    state = state || self.widgetObj.state;
                    stateContext = stateContext || state.context;

                    var stateMap = self.stateMaps[stateContext] || {},
                        stateValue = stateMap[state.name] || {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: []
                            },
                        style = stateValue.style,
                        classList = self.classList();

                    if (self.widgetObj.$element) {
                        self.widgetObj.$element.addClass(classList.join(" "));

                        if (state == self.widgetObj.state) {
                            for (var styleName in style) {
                                var styleValue = style[styleName];

                                if (toString.call(styleValue) === '[object Array]') {
                                    styleValue.forEach(function (value) {
                                        self.applyStyle(styleName, value);
                                    });
                                } else {
                                    self.applyStyle(styleName, styleValue);
                                }
                            }

                            self.updatePseudoStyle(state, stateContext);
                        }
                    }
                },
                clone: function (widgetObj) {
                    var self = this,
                        cloneObj = new StyleManager(widgetObj),
                        cloneMembers = _.difference(_.keys(self.MEMBERS), ["widgetObj", "stateMaps"]);

                    cloneMembers.forEach(function (member) {
                        cloneObj[member] = angular.copy(self[member]);
                    });

                    //style may contains property with array value
                    for (var stateContext in self.stateMaps) {
                        var stateMap = self.stateMaps[stateContext];
                        cloneObj.stateMaps[stateContext] = {};
                        for (var stateName in stateMap) {
                            var stateValue = stateMap[stateName];
                            cloneObj.stateMaps[stateContext][stateName] = {
                                style: {},
                                beforeStyle: {},
                                afterStyle: {},
                                styleSource: [],
                                classList: _.clone(stateValue.classList)
                            };

                            var style = stateValue.style,
                                cloneStyle = cloneObj.stateMaps[stateContext][stateName].style;

                            for (var styleName in style) {
                                cloneStyle[styleName] = angular.copy(style[styleName]);
                            }

                            var beforeStyle = stateValue.beforeStyle,
                                cloneBeforeStyle = cloneObj.stateMaps[stateContext][stateName].beforeStyle;

                            for (var styleName in beforeStyle) {
                                cloneBeforeStyle[styleName] = angular.copy(beforeStyle[styleName]);
                            }

                            var afterStyle = stateValue.afterStyle,
                                cloneAfterStyle = cloneObj.stateMaps[stateContext][stateName].afterStyle;

                            for (var styleName in beforeStyle) {
                                cloneAfterStyle[styleName] = angular.copy(afterStyle[styleName]);
                            }
                        }
                    }

                    return cloneObj;
                },
                removeState: function (state, stateContext) {
                    if (state) {
                        var self = this,
                            stateName = typeof state === "string" && state || state.name;

                        if (stateName) {
                            if (stateContext) {
                                var stateMap = self.stateMaps[stateContext];

                                stateMap && delete stateMap[stateName];
                            } else {
                                for (var key in self.stateMaps) {
                                    delete  self.stateMaps[key][stateName];
                                }
                            }
                        }
                    }
                },
                removeStateContext: function (stateContext) {
                    var self = this,
                        stateMap = self.stateMaps[stateContext];

                    if (stateMap) {
                        delete self.stateMaps[stateContext];
                    }
                },
                changeStateContext: function (oldContext, newContext) {
                    var self = this,
                        oldContext = arguments[0],
                        newContext = arguments[1],
                        stateMap;

                    if (newContext) {
                        stateMap = self.stateMaps[oldContext];

                        if (stateMap) {
                            self.stateMaps[newContext] = stateMap;
                            delete self.stateMaps[oldContext];
                        }
                    } else {
                        newContext = arguments[0];
                        stateMap = {};
                        for (var key in self.stateMaps) {
                            _.extend(stateMap, self.stateMaps[key]);
                            delete self.stateMaps[key];
                        }
                        self.stateMaps[newContext] = stateMap;
                    }
                }
            }),
            BaseSketchWidgetClass = Class({
                    CLASS_NAME: "BaseSketchWidget",
                    STATE_CONTEXT: new State("?", "*"),
                    MEMBERS: {
                        id: "",
                        name: "NO NAME",
                        childWidgets: [],
                        anchor: "",
                        initialStateOption: {name: "*"},
                        attr: {},
                        styleManager: null,
                        state: null,
                        stateContext: null,
                        states: [],
                        stateOptions: [],
                        $element: null,
                        resizable: true
                    },
                    initialize: function (id) {
                        var MEMBERS = arguments.callee.prototype.MEMBERS;

                        for (var member in MEMBERS) {
                            this[member] = angular.copy(MEMBERS[member]);
                        }
                        this.id = id || ("Widget_" + new Date().getTime());
                        this.stateContext = this.STATE_CONTEXT;
                        this.state = new State(this, this.initialStateOption.name, this.STATE_CONTEXT);
                        this.states.push(this.state);
                        this.styleManager = new StyleManager(this);

                        var proto = BaseSketchWidgetClass.prototype;
                        if (proto.objectMap) {
                            var value = proto.objectMap[this.id] || {callbacks: []};
                            proto.objectMap[this.id] = value;
                            value.item = this;
                            value.callbacks.forEach(function (callback) {
                                callback(value.item);
                            });
                            value.callbacks.splice(0, value.callbacks.length);
                        }
                    },
                    dispose: function () {
                        var self = this,
                            promiseArr = [];

                        self.childWidgets.forEach(function (obj) {
                            promiseArr.push(obj.dispose());
                        });

                        if (promiseArr.length) {
                            return $inject.uiUtilService.chain(
                                [
                                    function () {
                                        return $inject.$q.all(promiseArr);
                                    },
                                    function () {
                                        self.remove();
                                        return $inject.uiUtilService.getResolveDefer();
                                    }
                                ]
                            );
                        } else {
                            self.remove();
                            return $inject.uiUtilService.getResolveDefer();
                        }
                    },
                    startMatchReference: function () {
                        var proto = BaseSketchWidgetClass.prototype;
                        proto.objectMap = proto.objectMap || {};
                    },
                    matchReference: function (id, callback) {
                        var proto = BaseSketchWidgetClass.prototype;
                        if (proto.objectMap) {
                            var value = proto.objectMap[id] || {callbacks: []};
                            if (value.item) {
                                callback(value.item);
                            } else {
                                proto.objectMap[id] = value;
                                value.callbacks.push(callback);
                            }
                        }
                    },
                    endMatchReference: function () {
                        var proto = BaseSketchWidgetClass.prototype;
                        delete proto.objectMap;
                    },
                    toJSON: function () {
                        return _.extend(_.pick(this, ["id", "name", "anchor", "attr", "styleManager"]), {
                            state: this.state.id,
                            stateContext: this.stateContext.node !== "?" && this.stateContext.id || "",
                            childWidgets: $inject.uiUtilService.arrayOmit(this.childWidgets, "$$hashKey"),
                            states: $inject.uiUtilService.arrayOmit(this.states, "$$hashKey"),
                            stateOptions: $inject.uiUtilService.arrayOmit(this.stateOptions, "$$hashKey")
                        });
                    },
                    fromObject: function (obj) {
                        var self = this;

                        self.anchor = obj.anchor;
                        self.name = obj.name;
                        self.attr = _.omit(obj.attr, ["$$hashKey"]);
                        self.styleManager = StyleManager.prototype.fromObject(obj.styleManager);
                        self.styleManager.widgetObj = self;
                        obj.stateOptions.forEach(function (stateOption) {
                            self.stateOptions.push(_.omit(stateOption, ["$$hashKey"]));
                        });

                        self.states.splice(0, self.states.length);
                        var stateMap = {};
                        obj.states.forEach(function (s) {
                            var state = State.prototype.fromObject(s);
                            if (state) {
                                state.widgetObj = self;
                                self.states.push(state);
                                stateMap[state.id] = state;
                                if (!state.context) {
                                    state.context = self.STATE_CONTEXT;
                                }
                                if (state.id === obj.state) {
                                    self.state = state;
                                }
                            }
                        });

                        var classes = ["ElementSketchWidgetClass", "RepoSketchWidgetClass"];
                        obj.childWidgets.forEach(function (c) {
                            var className = c.CLASS_NAME,
                                childWidget;

                            classes.every(function (clazz) {
                                if (eval("className === {0}.prototype.CLASS_NAME".format(clazz))) {
                                    childWidget = eval("{0}.prototype.fromObject(c)".format(clazz));
                                    childWidget.stateContext = stateMap[c.stateContext];
                                    return false;
                                }

                                return true;
                            });
                            if (childWidget) {
                                childWidget.states.forEach(function (s) {
                                    if (typeof s.context === "string")
                                        s.context = stateMap[s.context];
                                });
                                self.childWidgets.push(childWidget);
                            }
                        });
                    },
                    isKindOf: function (className) {
                        return BaseSketchWidgetClass.prototype.CLASS_NAME == className;
                    },
                    clone: function (cloneObj, MEMBERS) {
                        var self = this;

                        _.extend(MEMBERS = MEMBERS || {}, BaseSketchWidgetClass.prototype.MEMBERS);
                        MEMBERS = _.omit(MEMBERS, ["id", "childWidgets", "anchor", "styleManager", "states", "state", "stateContext", "$element"]);
                        _.keys(MEMBERS).forEach(function (member) {
                            cloneObj[member] = angular.copy(self[member]);
                        });

                        cloneObj.styleManager = self.styleManager.clone(cloneObj);

                        cloneObj.states.splice(0, cloneObj.states.length);
                        self.states.forEach(function (s) {
                            cloneObj.states.push(s.clone(cloneObj));
                        });
                        cloneObj.setStateContext(self.stateContext);

                        self.childWidgets.forEach(function (obj) {
                            cloneObj.childWidgets.push(obj.clone());
                        });

                        return cloneObj;
                    },
                    handleEvent: function (fn) {
                        var self = this;

                        return $inject.uiUtilService.once(function () {
                            var result = fn() || {};

                            return result.then && result || $inject.uiUtilService.getResolveDefer();
                        }, null, $inject.angularConstants.eventThrottleInterval, "BaseSketchWidgetClass.handleEvent.{0}".format(self.id));
                    },
                    parent: function () {
                        var self = this,
                            $parent;

                        if (self.$element) {
                            if (self.anchor) {
                                var $anchor = self.$element.parent("[{0}='{1}']".format($inject.angularConstants.anchorAttr, self.anchor));
                                if ($anchor.length) {
                                    $parent = $anchor.closest("[ui-sketch-widget]");
                                }
                            } else {
                                $parent = self.$element.parent();
                            }
                        }

                        return $parent && $parent.data("widgetObject") || null;
                    },
                    parentElement: function (parentWidgetElement) {
                        var self = this,
                            parentElement;

                        if (self.$element) {
                            if (self.anchor) {
                                parentElement =
                                    parentWidgetElement && parentWidgetElement.find("[{0}='{1}']".format($inject.angularConstants.anchorAttr, self.anchor)) || self.$element.parent("[{0}='{1}']".format($inject.angularConstants.anchorAttr, self.anchor));
                            } else {
                                parentElement = parentWidgetElement || self.$element.parent("[ui-sketch-widget]");
                            }
                        }

                        return parentElement;
                    },
                    detach: function () {
                        var self = this;

                        if (self.$element) {
                            var parentWidgetObj = self.parent();

                            if (parentWidgetObj) {
                                var wIndex;
                                if (!parentWidgetObj.childWidgets.every(function (obj, index) {
                                        if (obj.id == self.id) {
                                            wIndex = index;
                                            return false;
                                        }

                                        return true;
                                    })) {
                                    parentWidgetObj.childWidgets.splice(wIndex, 1);
                                }
                            }

                            self.$element.detach();

                            return true;
                        }

                        return false;
                    },
                    removeChild: function (child) {
                        var self = this,
                            wIndex;

                        if (typeof child === "number")
                            wIndex = child;
                        else if (typeof child === "object") {
                            self.childWidgets.every(function (obj, index) {
                                if (obj.id == child.id) {
                                    wIndex = index;
                                    return false;
                                }

                                return true;
                            })
                        }

                        if (wIndex != null && wIndex < self.childWidgets.length) {
                            child = self.childWidgets[wIndex];
                            child.remove();

                            return child;
                        }
                    },
                    remove: function () {
                        var self = this,
                            parentWidgetObj = self.parent();

                        if (parentWidgetObj) {
                            var wIndex;
                            if (!parentWidgetObj.childWidgets.every(function (obj, index) {
                                    if (obj.id == self.id) {
                                        wIndex = index;
                                        return false;
                                    }

                                    return true;
                                })) {
                                parentWidgetObj.childWidgets.splice(wIndex, 1);
                            }
                        }

                        if (self.$element) {
                            self.$element.remove();
                            self.$element = null;
                        }
                        self.styleManager.removePseudoStyle();
                    },
                    attach: function (element) {
                        var self = this,
                            $element;

                        if (element) {
                            if (element.jquery) {
                                $element = element;
                            } else if (typeof element === "string" || angular.isElement(element)) {
                                $element = $(element);
                            }
                        } else {
                            $element = self.$element;
                        }

                        if ($element && $element[0].nodeType == 1 && $element.parent().length) {
                            var $parent = $element.parent(),
                                anchor = $parent.attr($inject.angularConstants.anchorAttr);

                            if (anchor) {
                                $parent = $parent.closest("[ui-sketch-widget]");
                            }

                            if ($parent.length) {
                                var widgetObj = $parent.data("widgetObject");

                                if (widgetObj) {
                                    if ($element.data("widgetObject") !== self) {
                                        self.$element && self.$element.parent().length && self.$element.detach();
                                        self.$element = $element;
                                        $element.data("widgetObject", self).attr("id", self.id);
                                    }

                                    self.anchor = anchor;
                                }
                            }
                        }
                    },
                    relink: function (containerWidget) {
                        var self = this;

                        return self.appendTo(containerWidget).then(
                            function () {
                                var promiseArr = [];

                                self.childWidgets.forEach(function (child) {
                                    promiseArr.push(child.relink(self));
                                });

                                if (promiseArr.length) {
                                    return $inject.$q.all(promiseArr);
                                } else {
                                    return $inject.uiUtilService.getResolveDefer(self);
                                }
                            },
                            function (err) {
                                return $inject.uiUtilService.getRejectDefer(err);
                            }
                        );
                    },
                    appendTo: function (container) {
                        if (container) {
                            var self = this,
                                widgetObj;

                            var $container;
                            if (container.jquery) {
                                $container = container;
                                widgetObj = $container.data("widgetObject");
                            } else if (typeof container === "string" || angular.isElement(container)) {
                                $container = $(container);
                                widgetObj = $container.data("widgetObject");
                            }

                            if (container.isKindOf && container.isKindOf("BaseSketchWidget")) {
                                $container = (container.$element = container.$element || $("<div />").data("widgetObject", container).attr("id", container.id));
                                widgetObj = container;
                            }

                            //ng-include may change dom element to comment which is invalid for later processing
                            if (self.$element && self.$element[0].nodeType != 1) {
                                self.$element = null;
                            }

                            if (!self.$element) {
                                self.$element = $("<div />").data("widgetObject", self).attr("id", self.id);
                                self.childWidgets.forEach(function (child) {
                                    if (child.$element) {
                                        child.$element.detach();
                                    } else {
                                        child.$element = $("<div />").data("widgetObject", child).attr("id", child.id);
                                    }
                                    child.$element.attr(child.attr);
                                    self.$element.append(child.$element);
                                })
                            } else {
                                if (!self.$element.parent()) {
                                    $container.append(self.$element);
                                }
                            }
                            self.$element.attr(self.attr);

                            if (widgetObj && widgetObj.isKindOf && widgetObj.isKindOf("BaseSketchWidget")) {
                                var childLeft, childTop, childWidth, childHeight;

                                //Keep offset and size or else they may be lost when the widget is detached later.
                                if (self.$element && self.$element.parent().length) {
                                    childLeft = self.$element.offset().left,
                                        childTop = self.$element.offset().top,
                                        childWidth = self.$element.width(),
                                        childHeight = self.$element.height();

                                    childLeft = Math.floor(childLeft * $inject.angularConstants.precision) / $inject.angularConstants.precision,
                                        childTop = Math.floor(childTop * $inject.angularConstants.precision) / $inject.angularConstants.precision,
                                        childWidth = Math.floor(childWidth * $inject.angularConstants.precision) / $inject.angularConstants.precision,
                                        childHeight = Math.floor(childHeight * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                }


                                var parent = self.parent(),
                                    isDetached = false;
                                if (parent && parent.id !== widgetObj.id) {
                                    isDetached = self.detach();
                                }

                                if (widgetObj.childWidgets.every(function (obj) {
                                        return obj.id != self.id;
                                    })) {
                                    widgetObj.childWidgets.push(self);
                                }

                                self.setStateContext(widgetObj.state);

                                var parentElement = self.parentElement(widgetObj.$element);
                                parentElement && !parentElement.find("#" + self.id).length && parentElement.append(self.$element);

                                if (widgetObj.isTemporary) {
                                    //Only widget whose element has already existed in html can be appended to temporary widget
                                    if ((self.$element && self.$element.parent().length) || isDetached) {
                                        var left,
                                            top,
                                            offsetLeft,
                                            offsetTop,
                                            width,
                                            height;

                                        if ($container && $container.parent().length) {
                                            left = offsetLeft = $container.offset().left, top = offsetTop = $container.offset().top, width = $container.width(), height = $container.height();
                                        } else {
                                            left = widgetObj.offsetLeft, top = widgetObj.offsetTop;

                                            var m = (widgetObj.css("width") || "").match(/([-\d\.]+)px$/);
                                            if (m && m.length == 2) width = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                            m = (widgetObj.css("height") || "").match(/([-\d\.]+)px$/);
                                            if (m && m.length == 2) height = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                            if (left == undefined || top == undefined || width == undefined || height == undefined) {
                                                left = childLeft, top = childTop, width = childWidth, height = childHeight;
                                            }
                                        }

                                        if (childLeft < left) {
                                            width += (left - childLeft);
                                            left = childLeft;
                                        }
                                        if (childTop < top) {
                                            height += (top - childTop);
                                            top = childTop;
                                        }
                                        if (childLeft + childWidth > left + width) {
                                            width = childLeft + childWidth - left;
                                        }
                                        if (childTop + childHeight > top + height) {
                                            height = childTop + childHeight - top;
                                        }

                                        if ((widgetObj.offsetLeft != undefined && widgetObj.offsetLeft != left) || (offsetLeft != undefined && offsetLeft != left)) {
                                            if (offsetLeft == undefined) {
                                                offsetLeft = widgetObj.offsetLeft;
                                            } else {
                                                m = (widgetObj.css("left") || "").match(/([-\d\.]+)px$/);
                                                if (m && m.length == 2) {
                                                    widgetObj.css("left", (Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision + left - offsetLeft) + "px");
                                                }
                                            }
                                            widgetObj.childWidgets.forEach(function (w) {
                                                var cm = (w.css("left") || "").match(/([-\d\.]+)px$/),
                                                    cLeft = parseFloat(cm[1]);
                                                w.css("left", (cLeft - (left - offsetLeft) + "px"));
                                            });
                                        }
                                        if ((widgetObj.offsetTop != undefined && widgetObj.offsetTop != top) || (offsetTop != undefined && offsetTop != top)) {
                                            if (offsetTop == undefined) {
                                                offsetTop = widgetObj.offsetTop;
                                            } else {
                                                m = (widgetObj.css("top") || "").match(/([-\d\.]+)px$/);
                                                if (m && m.length == 2) {
                                                    widgetObj.css("top", (Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision + top - offsetTop) + "px");
                                                }
                                            }
                                            widgetObj.childWidgets.forEach(function (w) {
                                                var cm = (w.css("top") || "").match(/([-\d\.]+)px$/),
                                                    cTop = parseFloat(cm[1]);
                                                w.css("top", (cTop - (top - offsetTop) + "px"));
                                            });
                                        }

                                        widgetObj.offsetLeft = left;
                                        widgetObj.offsetTop = top;

                                        widgetObj.css("width", width + "px");
                                        widgetObj.css("height", height + "px");

                                        childLeft -= left;
                                        childTop -= top;
                                        self.css("left", childLeft + "px");
                                        self.css("top", childTop + "px");
                                    }
                                }
                            } else {
                                if (!self.anchor && $container) {
                                    //Sketch widget can be appended to a jquery element.
                                    if (!$container.find("#" + self.id).length) {
                                        self.$element.detach();
                                        $container.append(self.$element);
                                        self.setStateContext(self.STATE_CONTEXT);
                                    }
                                }
                            }

                            $container = self.$element.parent();
                            if (self.offsetLeft != undefined) {
                                if ($container.length) {
                                    var containerLeft = $container.offset().left,
                                        containerTop = $container.offset().top;

                                    containerLeft = Math.floor(containerLeft * $inject.angularConstants.precision) / $inject.angularConstants.precision, containerTop = Math.floor(containerTop * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                    self.css("left", (self.offsetLeft - containerLeft) + "px");
                                    self.css("top", (self.offsetTop - containerTop) + "px");

                                    delete self.offsetLeft, delete self.offsetTop;
                                }
                            }

                            if ($container.length) {
                                self.childWidgets.forEach(function (child) {
                                    child.styleManager.draw();
                                });
                                self.styleManager.draw();

                                if (self.isTemporary) {
                                    self.$element.addClass("tempElement");
                                } else {
                                    self.$element.removeClass("tempElement");
                                }
                            }
                        }

                        return $inject.uiUtilService.getResolveDefer(self);
                    },
                    moveAfter: function () {
                        var self = this,
                            parentWidgetObj = self.parent();

                        if (parentWidgetObj) {
                            var wIndex;
                            if (!parentWidgetObj.childWidgets.every(function (obj, index) {
                                    if (obj.id == self.id) {
                                        wIndex = index;
                                        return false;
                                    }

                                    return true;
                                })) {
                                if (wIndex) {
                                    parentWidgetObj.childWidgets.splice(wIndex, 1);
                                    parentWidgetObj.childWidgets.splice(wIndex - 1, 0, self);
                                    if (self.$element) {
                                        self.$element.detach();
                                        self.$element.insertBefore(parentWidgetObj.childWidgets[wIndex].$element);
                                    }
                                }
                            }
                        }
                    },
                    moveBefore: function () {
                        var self = this,
                            parentWidgetObj = self.parent();

                        if (parentWidgetObj) {
                            var wIndex;
                            if (!parentWidgetObj.childWidgets.every(function (obj, index) {
                                    if (obj.id == self.id) {
                                        wIndex = index;
                                        return false;
                                    }

                                    return true;
                                })) {
                                if (wIndex < parentWidgetObj.childWidgets.length - 1) {
                                    parentWidgetObj.childWidgets.splice(wIndex, 1);
                                    parentWidgetObj.childWidgets.splice(wIndex + 1, 0, self);
                                    if (self.$element) {
                                        self.$element.detach();
                                        self.$element.insertAfter(parentWidgetObj.childWidgets[wIndex].$element);
                                    }
                                }
                            }
                        }
                    },
                    addClass: function (classes) {
                        this.styleManager.addClass.apply(this.styleManager, [classes, this.state, this.stateContext]);

                        return this;
                    },
                    removeClass: function (classes) {
                        this.styleManager.removeClass.apply(this.styleManager, [classes, this.state, this.stateContext]);

                        return this;
                    },
                    addOmniClass: function (classes) {
                        this.styleManager.addOmniClass.apply(this.styleManager, [classes]);

                        return this;
                    },
                    removeOmniClass: function (classes) {
                        this.styleManager.removeOmniClass.apply(this.styleManager, [classes]);

                        return this;
                    },
                    hasClass: function (clazz) {
                        return this.styleManager.hasClass.apply(this.styleManager, [clazz, this.state, this.stateContext]);
                    },
                    css: function () {
                        var args = Array.prototype.slice.call(arguments);
                        args.splice(0, 0, this.state, this.stateContext);

                        return this.styleManager.css.apply(this.styleManager, args);
                    },
                    pseudoCss: function () {
                        var args = Array.prototype.slice.call(arguments);
                        args.splice(0, 0, this.state, this.stateContext);

                        return this.styleManager.pseudoCss.apply(this.styleManager, args);
                    },
                    trackablePseudoCss: function () {
                        var args = Array.prototype.slice.call(arguments);
                        args.splice(0, 0, this.state, this.stateContext);

                        return this.styleManager.trackablePseudoCss.apply(this.styleManager, args);
                    },
                    showHide: function (showState) {
                        if (this.$element) {
                            this.$element.toggle(showState);

                            var isHidden = this.$element.css("display") === "none";
                            showState && isHidden && this.styleManager.updatePseudoStyle();
                            !showState && !isHidden && this.styleManager.removePseudoStyle();
                        }

                        return showState;
                    },
                    setState: function (value) {
                        if (value) {
                            var self = this,
                                stateName = typeof value === "string" && value || value.name,
                                stateFound = false;

                            if (stateName) {
                                if (self.states.every(function (s) {
                                        if (s.context.id == self.stateContext.id && s.name == stateName) {
                                            value = s;
                                            stateFound = true;
                                            return false;
                                        }

                                        return true;
                                    })) {
                                    if (self.stateOptions.every(function (stateOption) {
                                            if (stateOption.name == stateName) {
                                                value = new State(self, stateName, self.stateContext);
                                                return false;
                                            }

                                            return true;
                                        })) {
                                        if (self.initialStateOption.name == stateName)
                                            value = new State(self, self.initialStateOption.name, self.stateContext);
                                        else
                                            value = null;
                                    }
                                }

                                if (value && self.state != value) {
                                    !stateFound && self.states.push(value);
                                    self.unregisterTrigger();

                                    self.state = value;
                                    self.childWidgets.forEach(function (child) {
                                        child.setStateContext(self.state);
                                    });
                                    self.styleManager.draw();

                                    self.isPlaying && self.registerTrigger();
                                }
                            }
                        }
                    },
                    getState: function (stateName) {
                        var self = this,
                            state;

                        if (stateName) {
                            self.states.every(function (s) {
                                if (s.context.id = self.stateContext.id && s.name == stateName) {
                                    state = s;
                                    return false;
                                }

                                return true;
                            });
                        } else {
                            state = self.state;
                        }

                        return state;
                    },
                    addState: function (stateName) {
                        if (stateName) {
                            var self = this,
                                newState;

                            self.states.every(function (s) {
                                return s.context.id != self.stateContext.id || s.name != stateName;
                            }) && self.stateOptions.every(function (stateOption) {
                                if (stateOption.name == stateName) {
                                    newState = new State(self, stateName, self.stateContext);
                                    self.states.push(newState);
                                    return false;
                                }

                                return true;
                            });

                            return newState;
                        }
                    },
                    removeState: function (value) {
                        if (value) {
                            var self = this,
                                stateName = typeof value === "string" && value || value.name;

                            if (stateName && stateName !== self.initialStateOption.name) {
                                if (!self.stateOptions.every(function (s, i) {
                                        if (s.name == stateName) {
                                            return false;
                                        }
                                        return true;
                                    })) {
                                    self.styleManager.removeState(stateName);

                                    var index;
                                    if (!self.states.every(function (state, i) {
                                            if (state.context.id = self.stateContext.id && state.name === stateName) {
                                                index = i;
                                                self.childWidgets.forEach(function (child) {
                                                    child.removeStateContext(state);
                                                });

                                                return false;
                                            }

                                            return true;
                                        })) {
                                        self.states.splice(index, 1);
                                    }

                                    if (self.state.name == stateName) {
                                        self.setState(self.initialStateOption);
                                    } else {
                                        //Trigger state update on child widgets
                                        self.setState(self.state);
                                    }
                                }
                            }
                        }
                    },
                    addStateOption: function (value) {
                        var self = this;

                        if (value && value.name && value.name !== self.initialStateOption.name) {
                            if (self.stateOptions.every(function (s) {
                                    return s.name != value.name;
                                })) {
                                self.stateOptions.push(value);
                            }
                        }
                    },
                    removeStateOption: function (value) {
                        if (value) {
                            var self = this,
                                stateName = typeof value === "string" && value || value.name;

                            if (stateName && stateName !== self.initialStateOption.name) {
                                var index;
                                if (!self.stateOptions.every(function (s, i) {
                                        if (s.name == stateName) {
                                            index = i;
                                            return false;
                                        }
                                        return true;
                                    })) {
                                    self.styleManager.removeState(stateName);
                                    self.stateOptions.splice(index, 1);

                                    var arr = [];
                                    self.states.forEach(function (state, i) {
                                        if (state.name === stateName) {
                                            arr.push(i);
                                            self.childWidgets.forEach(function (child) {
                                                child.removeStateContext(state);
                                            });
                                        }
                                    });
                                    arr.length && arr.reverse() && arr.forEach(function (index) {
                                        self.states.splice(index, 1);
                                    });
                                    if (self.state.name == stateName) {
                                        self.setState(self.initialStateOption);
                                    } else {
                                        //Trigger state update on child widgets
                                        self.setState(self.state);
                                    }
                                }
                            }
                        }
                    },
                    getStates: function (context) {
                        var self = this,
                            context = context || self.stateContext,
                            states = _.filter(self.states, function (state) {
                                return state.context && state.context.id == context.id;
                            });

                        self.watchedStates = self.watchedStates || {};
                        self.watchedStates[context.id] = self.watchedStates[context.id] || [];
                        self.watchedStates[context.id].splice(0, self.watchedStates[context.id].length);

                        states.splice(0, 0, 0, 0);
                        Array.prototype.splice.apply(self.watchedStates[context.id], states);

                        return self.watchedStates[context.id];
                    },
                    setStateContext: function (value) {
                        var self = this;

                        if (value) {
                            if (self.states.every(function (state) {
                                    if (state.context === value && state.name == self.initialStateOption.name) {
                                        if (self.state !== state) {
                                            self.stateContext = value;
                                            self.setState(state);
                                        }
                                        return false;
                                    }

                                    return true;
                                })) {
                                if (self.state.context.node !== value.node) {
                                    var states = {};
                                    self.states.forEach(function (state) {
                                        if (state.context.name === value.name && !states[state.name]) {
                                            state.setContext(value);
                                            states[state.name] = state;
                                        } else {
                                            self.styleManager.removeState(state, state.context);
                                            self.childWidgets.forEach(function (child) {
                                                child.removeStateContext(state);
                                            });
                                        }
                                    });
                                    self.states = _.values(states);
                                    self.styleManager.changeStateContext(value);
                                }

                                self.stateContext = value;
                                self.setState(self.initialStateOption);
                            }
                        }
                    },
                    getStateContext: function () {
                        return this.stateContext;
                    },
                    removeStateContext: function (stateContext) {
                        var self = this,
                            arr = [];

                        self.states.forEach(function (state, i) {
                            if (state.context === stateContext) {
                                arr.push(i);
                                self.styleManager.removeStateContext(stateContext);
                                self.childWidgets.forEach(function (child) {
                                    child.removeStateContext(state);
                                });
                            }
                        });
                        arr.length && arr.reverse() && arr.forEach(function (index) {
                            self.states.splice(index, 1);
                        });

                        if (self.stateContext === stateContext) {
                            self.stateContext = null;
                        }
                    },
                    fillParent: function () {
                        var self = this,
                            $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                        if ($parent && $parent.length) {
                            var height = $inject.uiUtilService.calculateHeight($parent),
                                width = $inject.uiUtilService.calculateWidth($parent);

                            self.css("width", width + "px");
                            self.css("height", height + "px");
                            self.css("left", "0px");
                            self.css("top", "0px");
                        }
                    },
                    fillVertical: function () {
                        var self = this,
                            $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                        if ($parent && $parent.length) {
                            var height = $inject.uiUtilService.calculateHeight($parent);

                            self.css("height", height + "px");
                            self.css("top", "0px");
                        }
                    },
                    fillHorizontal: function () {
                        var self = this,
                            $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                        if ($parent && $parent.length) {
                            var width = $inject.uiUtilService.calculateWidth($parent);

                            self.css("width", width + "px");
                            self.css("left", "0px");
                        }
                    },
                    registerTrigger: function () {
                        var self = this;

                        self.state.transitions.forEach(function (transition) {
                            transition.registerTrigger(self);
                        });

                        return self;
                    },
                    unregisterTrigger: function () {
                        var self = this;

                        //TODO Need function to undo modification on widget element
                        self.state.transitions.forEach(function (transition) {
                            transition.unregisterTrigger();
                        });

                        return self;
                    },
                    playAnimation: function (animation) {
                        var self = this,
                            defer = $inject.$q.defer();

                        self.css(animation);
                        self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length && $inject.uiUtilService.onAnimationEnd(self.$element).then(function () {
                            defer.resolve();
                        }) || $inject.$timeout(function () {
                            defer.resolve();
                        });

                        return defer.promise;
                    },
                    getTrackablePseudoStyle: function () {
                        var args = Array.prototype.slice.call(arguments);
                        return this.trackablePseudoCss.apply(this, args);
                    },
                    setTrackablePseudoStyle: function (source) {
                        var self = this,
                            args = Array.prototype.slice.call(arguments);

                        if (args.length > 1 && args[1]) {
                            if (typeof args[1] === "string") {
                                if (args.length > 2) {
                                    self.trackablePseudoCss.apply(self, args);
                                }
                            } else if (typeof args[1] === "object") {
                                var styleSource = self.getTrackablePseudoStyle(source);
                                if (args[1] != styleSource) {
                                    ["style", "beforeStyle", "afterStyle"].forEach(function (pseudoStylePrefix) {
                                        var value = args[1][pseudoStylePrefix],
                                            pseudo = pseudoStylePrefix.replace(/style/i, "");

                                        self.trackablePseudoCss(source, pseudo, null);
                                        value && self.trackablePseudoCss(source, pseudo, value);
                                    });
                                }
                            }
                        }
                    },
                    setLinearGradientColor: function (value) {
                        var self = this;

                        if (value && value.colorStopList) {
                            if (value.colorStopList.length > 1) {
                                var x1, y1, x2, y2;
                                if (value.angle == 90) {
                                    x1 = 50;
                                    y1 = 100;
                                    x2 = 50;
                                    y2 = 0;
                                } else if (value.angle == 270) {
                                    x1 = 50;
                                    y1 = 0;
                                    x2 = 50;
                                    y2 = 100;
                                } else {
                                    var tan = Math.tan(value.angle);
                                    if (value.angle <= 45) {
                                        x1 = 0;
                                        y1 = 50 * ( 1 + tan);
                                        x2 = 100;
                                        y2 = 50 * (1 - tan);
                                    } else if (value.angle <= 135) {
                                        y1 = 100;
                                        x1 = 50 * (1 - 1 / tan);
                                        y2 = 0;
                                        x2 = 50 * (1 + 1 / tan);
                                    } else if (value.angle <= 225) {
                                        x1 = 100;
                                        y1 = 50 * (1 - tan);
                                        x2 = 0;
                                        y1 = 50 * (1 + tan);
                                    } else if (value.angle <= 315) {
                                        y1 = 0;
                                        x1 = 50 * (1 + 1 / tan);
                                        y2 = 100;
                                        x2 = 50 * (1 - 1 / tan);
                                    } else {
                                        x1 = 0;
                                        y1 = 50 + 50 * tan;
                                        x2 = 100;
                                        y2 = 50 - 50 * tan;
                                    }
                                    x1 = Math.ceil(x1);
                                    y1 = Math.ceil(y1);
                                    x2 = Math.ceil(x2);
                                    y2 = Math.ceil(y2);
                                }

                                var webkitStops = [], stops = [];
                                value.colorStopList.forEach(function (colorStop) {
                                    webkitStops.push("color-stop({1}%, {0})".format(colorStop.color, colorStop.percent));
                                    stops.push("{0} {1}%".format(colorStop.color, colorStop.percent));
                                });

                                var styles = [];
                                styles.push("-webkit-gradient(linear, {0}% {1}%, {2}% {3}%, {4})".format(x1, y1, x2, y2, webkitStops.join(",")));
                                $inject.uiUtilService.prefixedStyleValue("{0}linear-gradient({1}deg, {2})", value.angle, stops.join(",")).forEach(
                                    function (gradientStyleValue) {
                                        styles.push(gradientStyleValue);
                                    }
                                );
                                self.css("background", styles);
                            } else if (value.colorStopList.length == 1) {
                                var color = value.colorStopList[0].color;
                                color && self.css("background", color);
                            }
                        } else {
                            self.css("background", "");
                        }
                    },
                    getLinearGradientColor: function () {
                        var self = this,
                            value = self.css("background"),
                            colorObj = null;

                        if (toString.call(value) === '[object Array]') {
                            value.every(function (styleValue) {
                                var m = styleValue.match(/linear-gradient\((.+)\)/);
                                if (m && m.length == 2) {
                                    var n = m[1].match(/(\d)deg,(.+)$/);
                                    if (n && n.length == 3) {
                                        var angle = parseInt(n[1]),
                                            stops = n[2].split(","),
                                            colorStopList = [];

                                        stops.forEach(function (stopValue) {
                                            var s = stopValue.match(/(#\w+) (\d+)%/);
                                            if (s && s.length == 3) {
                                                var color = s[1];
                                                colorStopList.push({
                                                    percent: parseInt(s[2]),
                                                    color: color,
                                                    backgroundColor: $inject.uiUtilService.contrastColor(color) === "#ffffff" ? $inject.uiUtilService.lighterColor(color, 0.5) : $inject.uiUtilService.lighterColor(color, -0.5)
                                                });
                                            }
                                        });

                                        if (colorStopList.length) {
                                            for (var i = 1; i < colorStopList.length - 1; i++) {
                                                colorStopList[i].minPercent = colorStopList[i - 1].percent + 1;
                                                colorStopList[i].maxPercent = colorStopList[i + 1].percent - 1;
                                            }
                                            colorStopList[0].minPercent = 0;
                                            colorStopList[colorStopList.length - 1].maxPercent = 100;
                                            if (colorStopList.length > 1) {
                                                colorStopList[0].maxPercent = colorStopList[1].percent - 1;
                                                colorStopList[colorStopList.length - 1].minPercent = colorStopList[colorStopList.length - 2].percent + 1;
                                            }

                                            colorObj = {angle: angle, colorStopList: colorStopList};
                                        }
                                    }
                                }

                                return !colorObj;
                            });
                        } else if (typeof value === "string") {
                            colorObj = {
                                angle: 0,
                                colorStopList: [
                                    {
                                        percent: 0,
                                        color: value,
                                        minPercent: 0,
                                        maxPercent: 100,
                                        backgroundColor: $inject.uiUtilService.contrastColor(value) === "#ffffff" ? $inject.uiUtilService.lighterColor(value, 0.5) : $inject.uiUtilService.lighterColor(value, -0.5)
                                    }
                                ]
                            };
                        }

                        return colorObj;
                    },
                    setIsPlaying: function (value) {
                        if (!!this.isPlaying != !!value) {
                            this.unregisterTrigger(true);
                            this.isPlaying = value;
                            this.isPlaying && this.registerTrigger();
                        }
                    }
                }
            ),
            ElementSketchWidgetClass = Class(BaseSketchWidgetClass, {
                CLASS_NAME: "ElementSketchWidget",
                DEFAULT_STYLE: {
                    "width": "100px",
                    "height": "100px",
                    "linearGradientColor": {colorStopList: [{color: {color: "#ffffff", alpha: 1}, angle: 0}]}
                },
                MEMBERS: {
                    isElement: true,
                    isTemporary: false,
                    markdown: "",
                    html: ""
                },
                initialize: function (id, widgetsArr, isTemporary) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [id]);
                    var self = this,
                        MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.isElement = true;
                    this.isTemporary = false;
                    this.markdown = "";
                    this.html = "";

                    if (isTemporary != null) {
                        this.isTemporary = isTemporary;
                    }

                    if (widgetsArr && toString.apply(widgetsArr) == "[object Array]") {
                        widgetsArr.forEach(function (childWidget) {
                            childWidget.appendTo(self);
                        });
                    }

                    var self = this;
                    _.each(ElementSketchWidgetClass.prototype.DEFAULT_STYLE, function (styleValue, styleName) {
                        !self.css(styleName) && self.css(styleName, angular.copy(styleValue));
                    });
                },
                toJSON: function () {
                    var jsonObj = ElementSketchWidgetClass.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME", "html", "markdown"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new ElementSketchWidgetClass(obj.id);

                    ElementSketchWidgetClass.prototype.__proto__.fromObject.apply(ret, [obj]);
                    ret.markdown = obj.markdown;
                    ret.setHtml(obj.html);

                    return ret;
                },
                isKindOf: function (className) {
                    var self = this;

                    return ElementSketchWidgetClass.prototype.CLASS_NAME == className || ElementSketchWidgetClass.prototype.__proto__.isKindOf.apply(self, [className]);
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new ElementSketchWidgetClass();
                    _.extend(MEMBERS = MEMBERS || {}, ElementSketchWidgetClass.prototype.MEMBERS);

                    ElementSketchWidgetClass.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                appendTo: function (container) {
                    var self = this;

                    return ElementSketchWidgetClass.prototype.__proto__.appendTo.apply(self, [container]).then(
                        function () {
                            self.html && self.setHtml(self.html);
                            return $inject.uiUtilService.getResolveDefer(self);
                        },
                        function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        }
                    );
                },
                levelUp: function (widgetObj, doCompile, waiveDisassemble) {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var $parent = self.$element.parent(),
                            left = self.$element.offset().left,
                            top = self.$element.offset().top,
                            width = self.$element.width(),
                            height = self.$element.height(),
                            parentLeft = $parent.offset().left,
                            parentTop = $parent.offset().top,
                            wChildLeft = 0,
                            wChildTop = 0,
                            minChildLeft = 0,
                            minChildTop = 0,
                            maxChildRight = 0,
                            maxChildBottom = 0,
                            wIndex;

                        left = Math.floor(left * $inject.angularConstants.precision) / $inject.angularConstants.precision, top = Math.floor(top * $inject.angularConstants.precision) / $inject.angularConstants.precision, parentLeft = Math.floor(parentLeft * $inject.angularConstants.precision) / $inject.angularConstants.precision, parentTop = Math.floor(parentTop * $inject.angularConstants.precision) / $inject.angularConstants.precision, width = Math.floor(width * $inject.angularConstants.precision) / $inject.angularConstants.precision, height = Math.floor(height * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        self.childWidgets.forEach(function (childWidget, index) {
                            var childLeft = 0, childTop = 0, childWidth = 0, childHeight = 0;

                            var m = (childWidget.css("left") || "").match(/([-\d\.]+)px$/);
                            if (m && m.length == 2) childLeft = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                            m = (childWidget.css("top") || "").match(/([-\d\.]+)px$/);
                            if (m && m.length == 2) childTop = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                            m = (childWidget.css("width") || "").match(/([-\d\.]+)px$/);
                            if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                            m = (childWidget.css("height") || "").match(/([-\d\.]+)px$/);
                            if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                            if (childWidget.id == widgetObj.id) {
                                wChildLeft = (left - parentLeft) + childLeft;
                                wChildTop = (top - parentTop) + childTop;
                                wIndex = index;
                            } else {
                                if (childLeft < minChildLeft) minChildLeft = childLeft;
                                if (childTop < minChildTop) minChildTop = childTop;
                                if (childLeft + childWidth > maxChildRight) maxChildRight = childLeft + childWidth;
                                if (childTop + childHeight > maxChildBottom) maxChildBottom = childTop + childHeight;
                            }
                        });

                        if (wIndex != undefined) {
                            widgetObj = self.removeChild(wIndex);

                            widgetObj.css("left", wChildLeft + "px");
                            widgetObj.css("top", wChildTop + "px");
                            widgetObj.appendTo(self.$element.parent());

                            if (doCompile) {
                                var scope = angular.element(self.$element.parent()).scope();
                                $inject.$compile(self.$element.parent())(scope);
                            }

                            if (self.childWidgets.length == 1) {
                                !waiveDisassemble && self.disassemble();
                            } else {
                                left += minChildLeft, top += minChildTop, width = (maxChildRight - minChildLeft), height = (maxChildBottom - minChildTop);

                                self.css("left", (left - parentLeft) + "px");
                                self.css("top", (top - parentTop) + "px");
                                self.css("width", width + "px");
                                self.css("height", height + "px");
                            }
                        }
                    }
                },
                disassemble: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length && self.childWidgets.length) {
                        for (; self.childWidgets.length;) {
                            var childWidget = self.childWidgets[0];
                            self.levelUp(childWidget, false, true);
                        }

                        var $parent = self.$element.parent();

                        self.remove();

                        var scope = angular.element($parent).scope();
                        $inject.$compile($parent)(scope);
                    }
                },
                directContains: function (widgetObj) {
                    return !this.childWidgets.every(function (w) {
                        return w.id != widgetObj.id;
                    });
                },
                alignLeft: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var maxChildWidth = 0,
                            m = (self.css("left") || "").match(/([-\d\.]+)px$/),
                            firstChildLeft,
                            left;
                        if (m && m.length == 2) left = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("left") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildLeft = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildLeft != undefined) {
                            self.childWidgets.forEach(function (w) {
                                var childWidth,
                                    m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childWidth > maxChildWidth) maxChildWidth = childWidth;

                                w.css("left", "0px");
                            });

                            if (maxChildWidth) {
                                self.css("left", (left + firstChildLeft) + "px");
                                self.css("width", maxChildWidth + "px");
                            }
                        }
                    }
                },
                alignHorizontalCenter: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var width,
                            maxChildWidth = 0,
                            m = (self.css("left") || "").match(/([-\d\.]+)px$/),
                            firstChildLeft,
                            firstChildWidth,
                            left;
                        if (m && m.length == 2) left = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.css("width") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) width = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("left") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildLeft = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("width") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildLeft != undefined && firstChildWidth) {
                            self.childWidgets.forEach(function (w) {
                                var childWidth,
                                    m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childWidth > maxChildWidth) maxChildWidth = childWidth;
                            });

                            if (maxChildWidth) {
                                self.css("left", (left + firstChildLeft) + "px");
                                self.css("width", maxChildWidth + "px");

                                self.childWidgets.forEach(function (w) {
                                    var childWidth,
                                        m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                    if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                    if (childWidth) {
                                        w.css("left", ((maxChildWidth - childWidth) / 2) + "px");
                                    }
                                });
                            }
                        }
                    }
                },
                alignRight: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var width,
                            maxChildWidth = 0,
                            m = (self.css("left") || "").match(/([-\d\.]+)px$/),
                            firstChildLeft,
                            firstChildWidth,
                            left;
                        if (m && m.length == 2) left = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.css("width") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) width = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("left") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildLeft = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("width") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildLeft != undefined && firstChildWidth) {
                            self.childWidgets.forEach(function (w) {
                                var childWidth,
                                    m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childWidth > maxChildWidth) maxChildWidth = childWidth;
                            });

                            if (maxChildWidth) {
                                self.css("left", (left + firstChildLeft + firstChildWidth - maxChildWidth ) + "px");
                                self.css("width", maxChildWidth + "px");

                                self.childWidgets.forEach(function (w) {
                                    var childWidth,
                                        m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                    if (m && m.length == 2) childWidth = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                    if (childWidth) {
                                        w.css("left", (maxChildWidth - childWidth) + "px");
                                    }
                                });
                            }
                        }
                    }
                },
                alignTop: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var maxChildHeight = 0,
                            m = (self.css("top") || "").match(/([-\d\.]+)px$/),
                            firstChildTop,
                            top;
                        if (m && m.length == 2) top = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("top") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildTop = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildTop != undefined) {
                            self.childWidgets.forEach(function (w) {
                                var childHeight,
                                    m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childHeight > maxChildHeight) maxChildHeight = childHeight;

                                w.css("top", "0px");
                            });

                            if (maxChildHeight) {
                                self.css("top", (top + firstChildTop) + "px");
                                self.css("height", maxChildHeight + "px");
                            }
                        }
                    }
                },
                alignVerticalCenter: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var height,
                            maxChildHeight = 0,
                            m = (self.css("top") || "").match(/([-\d\.]+)px$/),
                            firstChildTop,
                            firstChildHeight,
                            top;
                        if (m && m.length == 2) top = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.css("height") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) height = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("top") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildTop = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("height") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildTop != undefined && firstChildHeight) {
                            self.childWidgets.forEach(function (w) {
                                var childHeight,
                                    m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childHeight > maxChildHeight) maxChildHeight = childHeight;
                            });

                            if (maxChildHeight) {
                                self.css("top", (top + firstChildTop) + "px");
                                self.css("height", maxChildHeight + "px");

                                self.childWidgets.forEach(function (w) {
                                    var childHeight,
                                        m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                    if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                    if (childHeight) {
                                        w.css("top", ((maxChildHeight - childHeight) / 2) + "px");
                                    }
                                });
                            }
                        }
                    }
                },
                alignBottom: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var height,
                            maxChildHeight = 0,
                            m = (self.css("top") || "").match(/([-\d\.]+)px$/),
                            firstChildTop,
                            firstChildHeight,
                            top;
                        if (m && m.length == 2) top = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.css("height") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) height = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("top") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildTop = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        m = (self.childWidgets[0].css("height") || "").match(/([-\d\.]+)px$/);
                        if (m && m.length == 2) firstChildHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (firstChildTop != undefined && firstChildHeight) {
                            self.childWidgets.forEach(function (w) {
                                var childHeight,
                                    m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                                if (childHeight > maxChildHeight) maxChildHeight = childHeight;
                            });

                            if (maxChildHeight) {
                                self.css("top", (top + firstChildTop + firstChildHeight - maxChildHeight ) + "px");
                                self.css("height", maxChildHeight + "px");

                                self.childWidgets.forEach(function (w) {
                                    var childHeight,
                                        m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                    if (m && m.length == 2) childHeight = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                    if (childHeight) {
                                        w.css("top", (maxChildHeight - childHeight) + "px");
                                    }
                                });
                            }
                        }
                    }
                },
                spanVertical: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var m = (self.css("height") || "").match(/([-\d\.]+)px$/),
                            height;

                        if (m && m.length == 2) height = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (height && self.childWidgets.length) {
                            var childHeight = Math.floor(height / self.childWidgets.length * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                            self.childWidgets.forEach(function (w, i) {
                                w.fillHorizontal && w.fillHorizontal();
                                w.css("height", childHeight + "px");
                                w.css("top", (i * childHeight) + "px");
                            });
                        }
                    }
                },
                spanHorizontal: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var m = (self.css("width") || "").match(/([-\d\.]+)px$/),
                            width;

                        if (m && m.length == 2) width = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (width && self.childWidgets.length) {
                            var childWidth = Math.floor(width / self.childWidgets.length * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                            self.childWidgets.forEach(function (w, i) {
                                w.fillVertical && w.fillVertical();
                                w.css("width", childWidth + "px");
                                w.css("left", (i * childWidth) + "px");
                            });
                        }
                    }
                },
                spaceVertical: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var m = (self.css("height") || "").match(/([-\d\.]+)px$/),
                            height;

                        if (m && m.length == 2) height = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (height && self.childWidgets.length > 1) {
                            var totalChildHeight = 0,
                                flowDownWidgets = [];

                            self.childWidgets.forEach(function (w) {
                                m = (w.css("height") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) totalChildHeight += Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                var top,
                                    index;
                                m = (w.css("top") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) {
                                    top = parseFloat(m[1]);
                                    flowDownWidgets.every(function (fw, j) {
                                        if (top < fw.top) {
                                            index = j;
                                            return false;
                                        }

                                        return true;
                                    });
                                    if (index == null) index = flowDownWidgets.length;
                                    flowDownWidgets.splice(index, 0, {top: top, widget: w});
                                }
                            });

                            var space = Math.floor((height - totalChildHeight) / (self.childWidgets.length - 1) * $inject.angularConstants.precision) / $inject.angularConstants.precision,
                                offset = 0;
                            flowDownWidgets.forEach(function (fw, i) {
                                if (i > 0) offset += space;
                                fw.widget.css("top", offset + "px");
                                m = (fw.widget.css("height") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) offset += Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                            });
                        }
                    }
                },
                spaceHorizontal: function () {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var m = (self.css("width") || "").match(/([-\d\.]+)px$/),
                            width;

                        if (m && m.length == 2) width = Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        if (width && self.childWidgets.length > 1) {
                            var totalChildWidth = 0,
                                flowLeftWidgets = [];

                            self.childWidgets.forEach(function (w) {
                                m = (w.css("width") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) totalChildWidth += Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                                var left,
                                    index;
                                m = (w.css("left") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) {
                                    left = parseFloat(m[1]);
                                    flowLeftWidgets.every(function (fw, j) {
                                        if (left < fw.left) {
                                            index = j;
                                            return false;
                                        }

                                        return true;
                                    });
                                    if (index == null) index = flowLeftWidgets.length;
                                    flowLeftWidgets.splice(index, 0, {left: left, widget: w});
                                }
                            });

                            var space = Math.floor((width - totalChildWidth) / (self.childWidgets.length - 1) * $inject.angularConstants.precision) / $inject.angularConstants.precision,
                                offset = 0;
                            flowLeftWidgets.forEach(function (fw, i) {
                                if (i > 0) offset += space;
                                fw.widget.css("left", offset + "px");
                                m = (fw.widget.css("width") || "").match(/([-\d\.]+)px$/);
                                if (m && m.length == 2) offset += Math.floor(parseFloat(m[1]) * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                            });
                        }
                    }
                },
                setTemporary: function (value) {
                    if (this.isTemporary != value && this.$element) {
                        if (value) {
                            this.$element.addClass("tempElement");
                        } else {
                            this.$element.removeClass("tempElement");
                        }
                        this.isTemporary = value;
                    }
                },
                zoomIn: function ($page) {
                    var self = this;

                    if ($page && self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var scaleX = $page.width() / self.$element.width(),
                            scaleY = $page.height() / self.$element.height(),
                            scale = Math.max(scaleX, scaleY);
                        scale = Math.floor(scale * $inject.angularConstants.precision) / $inject.angularConstants.precision;

                        var scaleStyleObj = $inject.uiUtilService.prefixedStyle("transform", "scale({0}, {1})", scale, scale);
                        self.$element.css(scaleStyleObj);

                        var pageLeft = $page.offset().left, pageTop = $page.offset().top;
                        pageLeft = Math.floor(pageLeft * $inject.angularConstants.precision) / $inject.angularConstants.precision, pageTop = Math.floor(pageTop * $inject.angularConstants.precision) / $inject.angularConstants.precision;
                        self.$element.offset({left: pageLeft, top: pageTop});

                        self.addClass("zoom");
                        self.zoomed = true;

                        return scale;
                    }
                },
                zoomOut: function () {
                    var self = this;

                    if (self.zoomed) {
                        var scaleStyleObj = $inject.uiUtilService.prefixedStyle("transform", "scale(1, 1)");
                        self.$element.css(scaleStyleObj);

                        self.$element.css({left: self.css("left"), top: self.css("top")});
                        self.removeClass("zoom");
                        self.zoomed = false;
                    }
                },
                setHtml: function (value) {
                    var self = this;

                    self.html = value || "";
                    if (self.$element) {
                        var $textNode = self.$element.find(".widgetText");
                        if (self.html) {
                            if (!$textNode.length) {
                                $textNode = $("<div />").addClass("widgetText markdown-body editormd-preview-container").prependTo(self.$element);
                            }
                            $textNode.empty();
                            $textNode.html(self.html);
                        } else {
                            $textNode.remove();
                        }
                    }
                }
            }),
            IncludeSketchWidgetClass = Class(BaseSketchWidgetClass, {
                CLASS_NAME: "IncludeSketchWidget",
                MEMBERS: {
                    template: ""
                },
                initialize: function (id, template) {
                    arguments.callee.prototype.__proto__.initialize.apply(this, [id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.template = template;
                },
                toJSON: function () {
                    var jsonObj = IncludeSketchWidgetClass.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME", "template"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var self = this;

                    self.template = obj.template;

                    IncludeSketchWidgetClass.prototype.__proto__.fromObject.apply(self, [obj]);

                    return self;
                },
                isKindOf: function (className) {
                    var self = this;

                    return IncludeSketchWidgetClass.prototype.CLASS_NAME == className || IncludeSketchWidgetClass.prototype.__proto__.isKindOf.apply(self, [className]);
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new IncludeSketchWidgetClass(null, this.template);
                    _.extend(MEMBERS = MEMBERS || {}, IncludeSketchWidgetClass.prototype.MEMBERS);

                    IncludeSketchWidgetClass.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                appendTo: function (container) {
                    var self = this;

                    return IncludeSketchWidgetClass.prototype.__proto__.appendTo.apply(self, [container]).then(
                        function () {
                            if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length && self.template) {
                                var defer = $inject.$q.defer();

                                $inject.uiUtilService.whilst(
                                    function () {
                                        return !angular.element(self.$element).scope();
                                    },
                                    function (callback) {
                                        callback();
                                    },
                                    function (err) {
                                        if (!err) {
                                            self.$element.attr("ng-include", "'" + self.template + "'");

                                            var $parent = self.$element.parent(),
                                                scope = angular.element(self.$element).scope();

                                            $inject.$compile(self.$element)(scope);

                                            $inject.uiUtilService.whilst(
                                                function () {
                                                    var $el = $parent.find("#" + self.id),
                                                        widgetScope = angular.element($el.find("[widget-container]:nth-of-type(1)").first().children()[0]).scope();

                                                    return !$el.length || !widgetScope
                                                        || widgetScope.widgetId !== self.id;
                                                }, function (callback) {
                                                    callback();
                                                }, function (err) {
                                                    if (!err) {
                                                        //Set scoped value on widget scope
                                                        self.attach($parent.find("#" + self.id));
                                                        self.$element.removeAttr("ng-include");
                                                        defer.resolve(self);
                                                    } else {
                                                        defer.reject(err);
                                                    }
                                                },
                                                $inject.angularConstants.loadCheckInterval,
                                                "IncludeSketchWidgetClass.appendTo.completionScanner.widgetScope." + self.id,
                                                $inject.angularConstants.loadRenderTimeout
                                            );
                                        } else {
                                            defer.reject(err);
                                        }
                                    },
                                    $inject.angularConstants.checkInterval,
                                    "IncludeSketchWidgetClass.appendTo." + self.id,
                                    $inject.angularConstants.renderTimeout
                                );

                                return defer.promise;
                            } else {
                                return $inject.uiUtilService.getRejectDefer("Invalid Element {0}".format(self.id));
                            }
                        }, function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        }
                    );
                },
                relink: function (containerWidget) {
                    return this.appendTo(containerWidget);
                },
                attach: function (element) {
                    var self = this;

                    IncludeSketchWidgetClass.prototype.__proto__.attach.apply(self, [element]);

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        self.$element.addClass($inject.angularConstants.widgetClasses.widgetIncludeAnchorClass);

                        if (!self.contentIncludeWatcher) {
                            self.contentIncludeWatcher = $inject.$rootScope.$on(
                                $inject.angularConstants.widgetEventPattern.format($inject.angularEventTypes.widgetContentIncludedEvent, self.id),
                                self.onContentIncluded());

                            //FIXME contentIncludeWatcher needs to be called when the holding page is switched off.
                        }
                    }
                },
                onContentIncluded: function () {
                    var self = this;

                    return $inject.uiUtilService.latestOnce(
                        function (event, obj) {
                            var defer = $inject.$q.defer();

                            if (obj && obj.widgetId == self.id && self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                                var childWidgets = self.childWidgets,
                                    containerWidget = childWidgets.length && childWidgets[0],
                                    widgetScope = angular.element(self.$element.find("[widget-container]:nth-of-type(1)").first().children()[0]).scope(),
                                    anchors = [];

                                IncludeSketchWidgetClass.prototype.__proto__.attach.apply(self, [obj.$element]);
                                self.$element.addClass($inject.angularConstants.widgetClasses.widgetIncludeAnchorClass);

                                containerWidget.childWidgets.forEach(function (child) {
                                    child.anchor && anchors.every(function (anchor) {
                                        return anchor !== child.anchor;
                                    }) && anchors.push(child.anchor);
                                });

                                //Set scoped value on widget scope
                                var configuration = {};
                                _.without(_.keys(self.widgetSpec.configuration), ["state", "handDownConfiguration"]).forEach(
                                    function (key) {
                                        var config = self.widgetSpec.configuration[key],
                                            value = config.pickedValue || config.defaultValue;

                                        if (value != null) {
                                            configuration[key] = config;
                                        }
                                    }
                                );

                                if (!_.isEmpty(configuration)) {
                                    self.setScopedValue(configuration);
                                }

                                if (anchors.length) {
                                    $inject.uiUtilService.whilst(
                                        function () {
                                            return !anchors.every(function (anchor) {
                                                return self.$element.find("[{0}='{1}']".format($inject.angularConstants.anchorAttr, anchor)).length;
                                            });
                                        }, function (callback) {
                                            callback();
                                        }, function (err) {
                                            if (err) {
                                                defer.reject(err);
                                            } else {
                                                var promiseArr = [];

                                                if (containerWidget) {
                                                    containerWidget.attach(self.$element.children()[0]);

                                                    containerWidget.addOmniClass($inject.angularConstants.widgetClasses.widgetContainerClass);

                                                    containerWidget.childWidgets.forEach(function (child) {
                                                        promiseArr.push(child.relink(containerWidget));
                                                    });
                                                }

                                                if (promiseArr.length) {
                                                    $inject.$q.all(promiseArr).then(
                                                        function () {
                                                            anchors.forEach(function (anchor) {
                                                                //Some anchors may appear in runtime after scoped value is set, which makes its child widgets uncompiled.
                                                                var $anchor = self.$element.find("[{0}='{1}']".format($inject.angularConstants.anchorAttr, anchor));
                                                                $anchor.length && $inject.$compile($anchor)(widgetScope);
                                                            });
                                                            defer.resolve(self);
                                                        },
                                                        function (err) {
                                                            defer.reject(err);
                                                        }
                                                    );
                                                } else {
                                                    defer.resolve(self);
                                                }
                                            }
                                        },
                                        $inject.angularConstants.loadCheckInterval,
                                        "IncludeSketchWidgetClass.onContentIncluded.anchors." + self.id,
                                        $inject.angularConstants.renderTimeout
                                    );
                                } else {
                                    defer.resolve(self);
                                }
                            } else {
                                defer.reject("Invalid Element {0}".format(self.id));
                            }

                            return defer.promise;
                        },
                        null,
                        $inject.angularConstants.unresponsiveInterval,
                        "IncludeSketchWidgetClass.onContentIncluded." + self.id
                    );
                }
            }),
            RepoSketchWidgetClass = Class(IncludeSketchWidgetClass, {
                CLASS_NAME: "RepoSketchWidget",
                DEFAULT_STYLE: {
                    "width": "100px",
                    "height": "100px",
                    "linearGradientColor": {colorStopList: [{color: {color: "#ffffff", alpha: 1}, angle: 0}]}
                },
                MEMBERS: {
                    isElement: true,
                    widgetSpec: null,
                    project: null
                },
                initialize: function (id, widgetSpec) {
                    arguments.callee.prototype.__proto__.initialize.apply(this, [id, widgetSpec && widgetSpec.template || ""]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.resizable = false;
                    this.widgetSpec = widgetSpec;

                    var self = this;
                    _.each(RepoSketchWidgetClass.prototype.DEFAULT_STYLE, function (styleValue, styleName) {
                        !self.css(styleName) && self.css(styleName, angular.copy(styleValue));
                    });
                },
                dispose: function () {
                    var self = this;

                    //Unreference artifact
                    $("head link[type='text/css'][widget={0}]".format(self.id)).remove();
                    $inject.$rootScope.loadedProject.unrefArtifact(self.widgetSpec.artifactId);

                    return RepoSketchWidgetClass.prototype.__proto__.dispose.apply(self).then(function () {
                        return $inject.appService.deleteConfigurableArtifact(self.widgetSpec.projectId, self.id, self.widgetSpec.artifactId);
                    }, function (err) {
                        return $inject.uiUtilService.getRejectDefer(err);
                    });
                },
                toJSON: function () {
                    var jsonObj = RepoSketchWidgetClass.prototype.__proto__.toJSON.apply(this);

                    var widgetSpec = _.pick(this.widgetSpec, ["libraryId", "libraryName", "artifactId", "name", "version", "type", "projectId"]),
                        configuration = {handDownConfiguration: {}}, handDownConfiguration = configuration.handDownConfiguration;

                    _.each(this.widgetSpec.configuration.handDownConfiguration, function (config, key) {
                        if (config.pickedValue != null) {
                            if (config.type === "boundWriteList") {
                                handDownConfiguration[key] = {pickedValue: $inject.uiUtilService.arrayOmit(config.pickedValue, "$$hashKey")};
                            } else {
                                handDownConfiguration[key] = {pickedValue: config.pickedValue};
                            }
                        }
                    });

                    _.each(_.omit(this.widgetSpec.configuration, "state", "handDownConfiguration"), function (config, key) {
                        if (config.pickedValue != null) {
                            if (config.type === "boundWriteList") {
                                configuration[key] = {pickedValue: $inject.uiUtilService.arrayOmit(config.pickedValue, "$$hashKey")};
                            } else {
                                configuration[key] = {pickedValue: config.pickedValue};
                            }
                        }
                    });

                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME"]), {
                        widgetSpec: _.extend(widgetSpec, {configuration: configuration})
                    });

                    return jsonObj;
                },
                fromObject: function (obj) {
                    var ret = new RepoSketchWidgetClass(obj.id, obj.widgetSpec);

                    RepoSketchWidgetClass.prototype.__proto__.fromObject.apply(ret, [obj]);

                    return ret;
                },
                isKindOf: function (className) {
                    var self = this;

                    return RepoSketchWidgetClass.prototype.CLASS_NAME == className || RepoSketchWidgetClass.prototype.__proto__.isKindOf.apply(self, [className]);
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new RepoSketchWidgetClass(null, this.widgetSpec);
                    _.extend(MEMBERS = MEMBERS || {}, RepoSketchWidgetClass.prototype.MEMBERS);

                    RepoSketchWidgetClass.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                css: function () {
                    var args = Array.prototype.slice.call(arguments);

                    //widgetContainer's size should be the same as that of its parent
                    if (this.childWidgets.length) {
                        var containerWidget = this.childWidgets[0];

                        switch (args.length) {
                            case 1:
                                if (typeof args[0] === "object") {
                                    var sizeStyle = _.pick(args[0], ["width", "height"]);

                                    if (!_.isEmpty(sizeStyle)) {
                                        containerWidget.css(sizeStyle);
                                    }
                                }
                                break;
                            case 2:
                                if (args[0] === "width" || args[0] === "height") {
                                    containerWidget.css(args[0], args[1]);
                                }
                                break;
                        }
                    }

                    return RepoSketchWidgetClass.prototype.__proto__.css.apply(this, args);
                },
                appendTo: function (container) {
                    var self = this;

                    return $inject.$rootScope.loadedProject.loadArtifact(self.widgetSpec.libraryId, self.widgetSpec.artifactId, self.widgetSpec.version).then(
                        function (loadedSpec) {
                            self.template = self.widgetSpec.template = loadedSpec.template;

                            var configuration = angular.copy(loadedSpec.configuration);
                            if (!_.isEmpty(self.widgetSpec.configuration)) {
                                if (!_.isEmpty(self.widgetSpec.configuration.handDownConfiguration)) {
                                    _.each(configuration.handDownConfiguration, function (config, key) {
                                        var item = self.widgetSpec.configuration.handDownConfiguration[key];
                                        if (item && item.pickedValue != null) {
                                            config.pickedValue = item.pickedValue;
                                        }
                                    })
                                }

                                _.each(_.omit(configuration, "state", "handDownConfiguration"), function (config, key) {
                                    var item = self.widgetSpec.configuration[key];
                                    if (item && item.pickedValue != null) {
                                        config.pickedValue = item.pickedValue;
                                    }
                                });
                            }
                            self.widgetSpec.configuration = configuration;

                            var stateConfiguration = loadedSpec.configuration.state;
                            if (stateConfiguration) {
                                var stateOptions = stateConfiguration.options;
                                stateOptions.forEach(function (option) {
                                    RepoSketchWidgetClass.prototype.__proto__.addStateOption.apply(self, [{name: option.name}]);

                                    if (self.states.every(function (s) {
                                            return s.context.id != self.stateContext.id || s.name != option.name;
                                        })) {
                                        self.states.push(new State(self, option.name, self.stateContext));
                                    }
                                });
                            }

                            return $inject.appService.addConfigurableArtifact(
                                self.widgetSpec.projectId,
                                self.id,
                                self.widgetSpec.libraryName,
                                self.widgetSpec.artifactId,
                                self.widgetSpec.type,
                                self.widgetSpec.version
                            ).then(
                                function () {
                                    return RepoSketchWidgetClass.prototype.__proto__.appendTo.apply(self, [container]);
                                },
                                function (err) {
                                    return $inject.uiUtilService.getRejectDefer(err);
                                }
                            );
                        },
                        function (err) {
                            return $inject.uiUtilService.getRejectDefer(err);
                        }
                    );
                },
                directContains: function (widgetObj) {
                    return !this.childWidgets.every(function (w) {
                        return w.id != widgetObj.id;
                    });
                },
                relink: function (containerWidget) {
                    return this.appendTo(containerWidget);
                },
                fillParent: function () {
                    var self = this,
                        $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                    if ($parent && $parent.length) {
                        RepoSketchWidgetClass.prototype.__proto__.fillParent.apply(self);

                        self.childWidgets.forEach(function (child) {
                            child.fillParent();
                        });
                    }
                },
                fillVertical: function () {
                    var self = this,
                        $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                    if ($parent && $parent.length) {
                        RepoSketchWidgetClass.prototype.__proto__.fillVertical.apply(self);

                        self.childWidgets.forEach(function (child) {
                            child.fillVertical();
                        });
                    }
                },
                fillHorizontal: function () {
                    var self = this,
                        $parent = self.$element && self.$element[0].nodeType == 1 && self.$element.parent();

                    if ($parent && $parent.length) {
                        RepoSketchWidgetClass.prototype.__proto__.fillHorizontal.apply(self);

                        self.childWidgets.forEach(function (child) {
                            child.fillHorizontal();
                        });
                    }
                },
                getScopedValue: function (key) {
                    var self = this;

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        var scope = angular.element(self.$element.find("[widget-container]:nth-of-type(1)").first().children()[0]).scope();

                        return scope[key];
                    }

                    return null;
                },
                setScopedValue: function (key, value) {
                    var self = this,
                        defer = $inject.$q.defer();

                    function scopeSetterHandler(scope, key, value) {
                        var setterName = ("set" + key.charAt(0).toUpperCase() + key.substr(1)),
                            setter = scope[setterName];
                        if (setter) {
                            setter.apply(scope, [value]);
                        } else {
                            //Scoped value may be unset initially when linking directive even after its already set, which will arouse
                            //unexpected result, to avoid such case setting needs to be stored in scoped 'configuration'.
                            if (scope.configuration) {
                                scope.configuration[key] = value;
                            }
                            scope[key] = value;
                        }
                    }

                    if (self.$element && self.$element[0].nodeType == 1 && self.$element.parent().length) {
                        $inject.uiUtilService.whilst(function () {
                                var scope = angular.element(self.$element.find("[widget-container]:nth-of-type(1)").first().children()[0]).scope();
                                return !scope || scope.widgetId !== self.id;
                            }, function (callback) {
                                callback();
                            }, function (err) {
                                if (!err) {
                                    var scope = angular.element(self.$element.find("[widget-container]:nth-of-type(1)").first().children()[0]).scope();

                                    if (typeof key === "object") {
                                        _.each(key, function (item, itemKey) {
                                            if (item.type === "size") {
                                                var m = ((item.pickedValue || item.defaultValue) || "").match(/([-\d\.]+)(px|em|%)+$/)
                                                if (m && m.length == 3) {
                                                    scope[itemKey] = item.pickedValue || item.defaultValue;
                                                }
                                            } else {
                                                scopeSetterHandler(scope, itemKey, item.pickedValue || item.defaultValue);
                                            }
                                        });
                                    }
                                    else if (typeof key === "string") {
                                        scopeSetterHandler(scope, key, value);
                                    }

                                    defer.resolve(self);
                                } else {
                                    defer.reject(err);
                                }
                            },
                            $inject.angularConstants.checkInterval,
                            "RepoSketchWidgetClass.setScopedValue." + self.id,
                            $inject.angularConstants.renderTimeout
                        )
                    } else {
                        return defer.reject("Invalid Element {0}".format(self.id));
                    }

                    return defer.promise;
                },
                getConfiguration: function (key) {
                    var self = this,
                        config = self.widgetSpec.configuration[key] || self.widgetSpec.configuration.handDownConfiguration[key];

                    if (config.type === "boundWriteList") {
                        config.pickedValue = config.pickedValue || [];
                    }

                    return config.pickedValue != null ? config.pickedValue : config.defaultValue;
                },
                setConfiguration: function (key, value) {
                    var self = this,
                        config = self.widgetSpec.configuration[key] || self.widgetSpec.configuration.handDownConfiguration[key];

                    if (value != config.defaultValue) {
                        if (value != null) {
                            config.pickedValue = value;
                        } else {
                            delete config.pickedValue;
                        }

                        config.handDown && self.setHandDownConfiguration(key, value) || self.setScopedValue(key, value || config.defaultValue);
                    }
                },
                setHandDownConfiguration: function (key, value) {
                    var self = this,
                        index;

                    //handDownList will be flushed after sending back configuration items to server
                    self.handDownConfigurationList = self.handDownConfigurationList || [];
                    self.handDownConfigurationList.every(function (item, i) {
                        if (item.key === key) {
                            index = i;
                            item.value = value;
                            return false;
                        }

                        return true;
                    });
                    if (index == null) {
                        self.handDownConfigurationList.push({
                            key: key,
                            value: value
                        });
                    } else {
                        value == null && self.handDownConfigurationList.splice(index, 1);
                    }

                    return true;
                },
                applyHandDownConfiguration: function () {
                    var self = this;

                    if (self.handDownConfigurationList && self.handDownConfigurationList.length) {
                        var configurationArr = [];

                        _.each(self.widgetSpec.configuration.handDownConfiguration, function (config, key) {
                            if (config.pickedValue != null) {
                                if (config.type === "color") {
                                    configurationArr.push({
                                        key: key,
                                        value: config.pickedValue.alphaColor || config.pickedValue.color
                                    });
                                } else {
                                    configurationArr.push({key: key, value: config.pickedValue});
                                }
                            }
                        });

                        return $inject.$q.all(
                            [
                                $inject.$rootScope.loadedProject.save(),
                                $inject.appService.updateConfigurableArtifact(self.widgetSpec.projectId, self.id, self.widgetSpec.artifactId, configurationArr).then(
                                    function () {
                                        self.handDownConfigurationList.splice(0, self.handDownConfigurationList.length);

                                        return $inject.uiUtilService.getResolveDefer();
                                    },
                                    function (err) {
                                        $inject.uiUtilService.getRejectDefer(err);
                                    }
                                )
                            ]
                        );
                    } else {
                        return $inject.uiUtilService.getResolveDefer();
                    }
                },
                addState: function () {
                },
                removeState: function () {
                },
                addStateOption: function () {
                },
                removeStateOption: function () {
                },
                setState: function (value) {
                    RepoSketchWidgetClass.prototype.__proto__.setState.apply(this, [value]);

                    var stateName = typeof value === "string" && value || value.name;

                    this.setScopedValue("state", stateName);
                },
                setStateContext: function (value) {
                    var self = this;

                    if (value) {
                        RepoSketchWidgetClass.prototype.__proto__.setStateContext.apply(self, [value]);

                        //Initialize states from the widget setting
                        var stateOptions = angular.copy(self.stateOptions);
                        _.union([self.initialStateOption], stateOptions).forEach(function (stateOption) {
                            if (self.states.every(function (s) {
                                    return s.context.id != self.stateContext.id || s.name != stateOption.name;
                                })) {
                                self.states.push(new State(self, stateOption.name, self.stateContext));
                            }
                        });
                    }
                }
            }),
            PageSketchWidgetClass = Class(BaseSketchWidgetClass, {
                CLASS_NAME: "PageSketchWidget",
                MEMBERS: {},
                initialize: function (id) {
                    this.initialize.prototype.__proto__.initialize.apply(this, [id]);
                    var MEMBERS = arguments.callee.prototype.MEMBERS;

                    for (var member in MEMBERS) {
                        this[member] = angular.copy(MEMBERS[member]);
                    }

                    this.resizable = false;
                },
                toJSON: function () {
                    var jsonObj = PageSketchWidgetClass.prototype.__proto__.toJSON.apply(this);
                    _.extend(jsonObj, _.pick(this, ["CLASS_NAME"]));

                    return jsonObj;
                },
                fromObject: function (obj) {
                    //Match marshalled widget id with created widget object.
                    //Some objects may marshall widget id instead of the object. In order to restore object reference, match process will be handled.
                    PageSketchWidgetClass.prototype.__proto__.startMatchReference.apply(null);

                    var ret = new PageSketchWidgetClass(obj.id);
                    PageSketchWidgetClass.prototype.__proto__.fromObject.apply(ret, [obj]);

                    PageSketchWidgetClass.prototype.__proto__.endMatchReference.apply(null);

                    return ret;
                },
                clone: function (cloneObj, MEMBERS) {
                    cloneObj = cloneObj || new PageSketchWidgetClass();
                    _.extend(MEMBERS = MEMBERS || {}, PageSketchWidgetClass.prototype.MEMBERS);

                    PageSketchWidgetClass.prototype.__proto__.clone.apply(this, [cloneObj, MEMBERS]);

                    return cloneObj;
                },
                isKindOf: function (className) {
                    var self = this;

                    return PageSketchWidgetClass.prototype.CLASS_NAME == className || PageSketchWidgetClass.prototype.__proto__.isKindOf.apply(self, [className]);
                },
                css: function () {
                    var args = Array.prototype.slice.call(arguments);

                    //Page's left and top should be fixed to "0px"
                    switch (args.length) {
                        case 1:
                            if (args[0] === "left" || args[0] === "top") {
                                return "0px";
                            } else if (typeof args[0] === "object") {
                                if (_.isEmpty((_.omit(args[0], ["left", "top"])))) {
                                    return this;
                                }
                            }
                            break;
                        case 2:
                            if (args[0] === "left" || args[0] === "top") {
                                return this;
                            }
                            break;
                    }

                    return PageSketchWidgetClass.prototype.__proto__.css.apply(this, args);
                },
                pseudoCss: function (pseudo) {
                    var args = Array.prototype.slice.call(arguments);

                    //Page's left and top should be fixed to "0px"
                    if (pseudo != null && !pseudo) {
                        switch (args.length) {
                            case 2:
                                if (args[1] === "left" || args[1] === "top") {
                                    return "0px";
                                } else if (typeof args[1] === "object") {
                                    if (_.isEmpty((_.omit(args[1], ["left", "top"])))) {
                                        return this;
                                    }
                                }
                                break;
                            case 3:
                                if (args[1] === "left" || args[1] === "top") {
                                    return this;
                                }
                                break;
                        }
                    }

                    return PageSketchWidgetClass.prototype.__proto__.pseudoCss.apply(this, args);
                },
                trackablePseudoCss: function (source, pseudo) {
                    var args = Array.prototype.slice.call(arguments);

                    //Page's left and top should be fixed to "0px"
                    if (pseudo != null && !pseudo) {
                        switch (args.length) {
                            case 3:
                                if (args[2]) {
                                    if (args[2] === "left" || args[2] === "top") {
                                        return "0px";
                                    } else if (typeof args[2] === "object") {
                                        if (_.isEmpty((_.omit(args[2], ["left", "top"])))) {
                                            return this;
                                        }
                                    }
                                }
                                break;
                            case 4:
                                if (args[2] === "left" || args[2] === "top") {
                                    return this;
                                }
                                break;
                        }
                    }

                    return PageSketchWidgetClass.prototype.__proto__.trackablePseudoCss.apply(this, args);
                },
                parent: function () {
                    return null;
                },
                parentElement: function () {
                    var self = this;

                    return self.$element && self.$element[0].nodeType == 1 && self.$element.parent() || null;
                }
            });

        Service.prototype.createWidgetObj = function (element) {
            var self = this,
                $el,
                widgetObj;

            if (element.jquery) {
                $el = element;
            } else if (typeof element === "string" || angular.isElement(element)) {
                $el = $(element);
            }

            widgetObj = $el && $el.data("widgetObject");

            if ($el && $el.attr("ui-sketch-widget") != null && !widgetObj) {
                var $parentElement = $el.parent("[{0}]".format($inject.angularConstants.anchorAttr)),
                    anchor;

                if ($parentElement.length) {
                    anchor = $parentElement.attr($inject.angularConstants.anchorAttr);
                    $parentElement = $parentElement.closest("[ui-sketch-widget]");
                } else {
                    $parentElement = $el.parent("[ui-sketch-widget]");
                }

                if ($parentElement.length) {
                    var parentWidgetObj = $parentElement.data("widgetObject");

                    //Directive ng-include will recreate element which have no widget object attached to.
                    parentWidgetObj = parentWidgetObj || self.createWidgetObj($parentElement);

                    if (parentWidgetObj) {
                        var id = $el.attr("id");

                        //Fetch widget object if found
                        if (id) {
                            parentWidgetObj.childWidgets.every(function (child) {
                                if (child.id === id) {
                                    widgetObj = child;
                                    return false;
                                }

                                return true;
                            });

                            if (widgetObj && widgetObj.isKindOf("RepoSketchWidget")) {
                                $el.addClass(self.angularConstants.widgetClasses.widgetIncludeAnchorClass);
                            }
                        } else if ($el.hasClass(self.angularConstants.widgetClasses.widgetContainerClass) && parentWidgetObj.isKindOf("RepoSketchWidget")) {
                            if (parentWidgetObj.childWidgets.length) {
                                widgetObj = parentWidgetObj.childWidgets[0];
                            }
                        }

                        if (!widgetObj) {
                            widgetObj = new ElementSketchWidgetClass();

                            widgetObj.attr["ui-sketch-widget"] = "";
                            widgetObj.attr["is-playing"] = "$root.sketchWidgetSetting.isPlaying";
                            widgetObj.attr["scale"] = "$root.sketchWidgetSetting.scale";
                            widgetObj.attr["ng-class"] = "{'isPlaying': $root.sketchWidgetSetting.isPlaying}";
                            widgetObj.addOmniClass(self.angularConstants.widgetClasses.widgetClass);

                            widgetObj.$element = $el;
                            widgetObj.anchor = anchor;
                            $el.attr("id", widgetObj.id);
                            $el.data("widgetObject", widgetObj);

                            ElementSketchWidgetClass.prototype.appendTo.apply(widgetObj, [parentWidgetObj]);
                        } else {
                            widgetObj.$element = $el;
                            widgetObj.anchor = anchor;
                            $el.attr("id", widgetObj.id);
                            $el.data("widgetObject", widgetObj);
                        }
                    }
                }
            }

            return widgetObj;
        }

        Service.prototype.createWidget = function (containerElement, widgetObj) {
            var self = this,
                $container;

            if (containerElement.jquery) {
                $container = containerElement;
            } else if (typeof containerElement === "string" || angular.isElement(containerElement)) {
                $container = $(containerElement);
            }

            if ($container) {
                var $parent,
                    anchor;

                if ($container.hasClass(self.angularConstants.widgetClasses.holderClass) || $container.hasClass(self.angularConstants.widgetClasses.widgetClass)) {
                    $parent = $container;
                } else if ($container.attr(self.angularConstants.anchorAttr) != null) {
                    $parent = $container.closest("[ui-sketch-widget]");
                    anchor = $container.attr(self.angularConstants.anchorAttr);
                }

                if ($parent) {
                    widgetObj = widgetObj || new ElementSketchWidgetClass();
                    widgetObj.anchor = anchor;
                    widgetObj.attr["ui-sketch-widget"] = "";
                    widgetObj.attr["is-playing"] = "$root.sketchWidgetSetting.isPlaying";
                    widgetObj.attr["scale"] = "$root.sketchWidgetSetting.scale";
                    widgetObj.attr["ng-class"] = "{'isPlaying': $root.sketchWidgetSetting.isPlaying}";
                    widgetObj.addOmniClass(self.angularConstants.widgetClasses.widgetClass);
                    widgetObj.appendTo($parent);

                    var scope = angular.element($container).scope();
                    $inject.$compile($container)(scope);

                    return widgetObj;
                }
            }
        }

        Service.prototype.createRepoWidget = function (containerElement, widgetSpec) {
            var self = this,
                widgetObj = new RepoSketchWidgetClass(null, widgetSpec);
            widgetObj.attr["ui-sketch-widget"] = "";
            widgetObj.attr["is-playing"] = "$root.sketchWidgetSetting.isPlaying";
            widgetObj.attr["scale"] = "$root.sketchWidgetSetting.scale";
            widgetObj.attr["ng-class"] = "{'isPlaying': $root.sketchWidgetSetting.isPlaying}";
            widgetObj.addOmniClass(self.angularConstants.widgetClasses.widgetClass);

            self.$rootScope.loadedProject.refArtifact(widgetSpec.libraryId, widgetSpec.artifactId, widgetSpec.name, widgetSpec.version);

            if (containerElement.jquery) {
                $container = containerElement;
            } else if (typeof containerElement === "string" || angular.isElement(containerElement)) {
                $container = $(containerElement);
            }

            if ($container) {
                var $parent,
                    anchor;

                if ($container.hasClass(self.angularConstants.widgetClasses.holderClass) || $container.hasClass(self.angularConstants.widgetClasses.widgetClass)) {
                    $parent = $container;
                } else if ($container.attr(self.angularConstants.anchorAttr) != null) {
                    $parent = $container.closest("[ui-sketch-widget]");
                    anchor = $container.attr(self.angularConstants.anchorAttr);
                }

                if ($parent) {
                    widgetObj.anchor = anchor;

                    return widgetObj.appendTo($parent).then(
                        function () {
                            return self.uiUtilService.getResolveDefer(widgetObj);
                        },
                        function (err) {
                            return self.uiUtilService.getRejectDefer(err);
                        }
                    );

                }
            }

            return self.uiUtilService.getRejectDefer();
        }

        Service.prototype.copyWidget = function (widgetObj, containerElement) {
            var self = this,
                cloneObj = widgetObj.clone(),
                $container;

            if (containerElement.jquery) {
                $container = containerElement;
            } else if (typeof containerElement === "string" || angular.isElement(containerElement)) {
                $container = $(containerElement);
            }

            if ($container) {
                var $parent,
                    anchor;

                if ($container.hasClass(self.angularConstants.widgetClasses.holderClass) || $container.hasClass(self.angularConstants.widgetClasses.widgetClass)) {
                    $parent = $container;
                } else if ($container.attr(self.angularConstants.anchorAttr) != null) {
                    $parent = $container.closest("[ui-sketch-widget]");
                    anchor = $container.attr(self.angularConstants.anchorAttr);
                }
            }

            if ($parent) {
                cloneObj.anchor = anchor;
                cloneObj.removeOmniClass(self.angularConstants.widgetClasses.activeClass);

                return cloneObj.appendTo($parent).then(function () {
                    var scope = angular.element(cloneObj.$element.parent()).scope();
                    self.$compile(cloneObj.$element.parent())(scope);

                    return self.uiUtilService.whilst(
                        function () {
                            return !cloneObj.$element.data("hammer");
                        }, function (callback) {
                            callback();
                        }, function () {
                            var manager = cloneObj.$element.data("hammer"),
                                element = cloneObj.$element.get(0);

                            manager.emit("tap", {target: element, srcEvent: {target: element}});
                        },
                        self.angularConstants.checkInterval,
                        "Service.copyWidget." + cloneObj.id,
                        self.angularConstants.renderTimeout).then(
                        function () {
                            return self.uiUtilService.getResolveDefer(cloneObj);
                        }, function () {
                            return self.uiUtilService.getRejectDefer();
                        }
                    );
                });


                return self.uiUtilService.getRejectDefer();
            }
        }

        Service.prototype.createComposite = function (widgetObjs, isTemporary) {
            if (widgetObjs && widgetObjs.length) {
                var self = this,
                    containerId = null,
                    containerElement = null,
                    widgetArr = [];

                widgetObjs.forEach(function (w) {
                    if (w.isElement) {
                        if (!w.$element || !w.$element.parent().length) {
                            widgetArr.push(w);
                        } else {
                            var $parent = w.$element.parent(),
                                parentId = $parent.data("widgetObject").id;
                            containerId = containerId || parentId;
                            containerElement = containerElement || ($parent.length && $parent);
                            if (!parentId || !containerId || containerId == parentId) {
                                widgetArr.push(w);
                            }
                        }
                    }
                });

                if (widgetArr.length > 1 && containerElement) {
                    var compositeObj = new ElementSketchWidgetClass(null, widgetArr, isTemporary);

                    compositeObj.attr["ui-sketch-widget"] = "";
                    compositeObj.attr["is-playing"] = "$root.sketchWidgetSetting.isPlaying";
                    compositeObj.attr["scale"] = "$root.sketchWidgetSetting.scale";
                    compositeObj.attr["ng-class"] = "{'isPlaying': $root.sketchWidgetSetting.isPlaying}";
                    compositeObj.addOmniClass(self.angularConstants.widgetClasses.widgetClass);
                    compositeObj.appendTo(containerElement);

                    var scope = angular.element(compositeObj.$element.parent()).scope();
                    self.$compile(compositeObj.$element.parent())(scope);

                    return compositeObj;
                }
            }

            return null;
        }

        Service.prototype.createPage = function (holderElement, pageObj) {
            var self = this,
                defer = self.$q.defer();

            if (typeof holderElement === "string" || angular.isElement(holderElement)) {
                holderElement = $(holderElement);
            }

            if (!pageObj) {
                pageObj = new PageSketchWidgetClass();
                pageObj.attr["ui-sketch-widget"] = "";
                pageObj.attr["is-playing"] = "$root.sketchWidgetSetting.isPlaying";
                pageObj.attr["scale"] = "$root.sketchWidgetSetting.scale";
                pageObj.attr["ng-class"] = "{'isPlaying': $root.sketchWidgetSetting.isPlaying}";
                pageObj.addOmniClass(self.angularConstants.widgetClasses.holderClass);
            }

            self.uiUtilService.whilst(
                function () {
                    return !angular.element(holderElement).scope();
                }, function (callback) {
                    callback();
                }, function (err) {
                    if (!err) {
                        pageObj.relink(holderElement).then(
                            function () {
                                var scope = angular.element(holderElement).scope();
                                self.$compile(holderElement)(scope);

                                defer.resolve(pageObj);
                            }, function (err) {
                                defer.reject(err);
                            }
                        );
                    } else {
                        defer.reject(err);
                    }
                },
                self.angularConstants.checkInterval,
                "Service.createPage." + pageObj.id,
                self.angularConstants.renderTimeout);

            return defer.promise;
        }

        Service.prototype.copyPage = function (pageObj, holderElement) {
            var self = this,
                cloneObj = pageObj.clone();

            cloneObj.removeOmniClass(self.angularConstants.widgetClasses.activeClass);

            return cloneObj.appendTo(holderElement).then(
                function () {
                    return self.uiUtilService.whilst(
                        function () {
                            return !angular.element(cloneObj.$element.parent()).scope();
                        }, function (callback) {
                            callback();
                        }, function () {
                            var scope = angular.element(cloneObj.$element.parent()).scope();
                            $inject.$compile(cloneObj.$element.parent())(scope);
                        }).then(function () {
                            var defer = self.$q.defer();

                            self.$timeout(function () {
                                defer.resolve(cloneObj);
                            });

                            return defer.promise;
                        },
                        self.angularConstants.checkInterval,
                        "Service.copyPage." + cloneObj.id,
                        self.angularConstants.renderTimeout);

                },
                function (err) {
                    return self.uiUtilService.getRejectDefer(err);
                }
            );
        }

        Service.prototype.fromObject = function (obj) {
            var className = obj.CLASS_NAME,
                classes = ["PageSketchWidgetClass"],
                ret;

            classes.every(function (clazz) {
                if (eval("className === {0}.prototype.CLASS_NAME".format(clazz))) {
                    ret = eval("{0}.prototype.fromObject(obj)".format(clazz));
                    return false;
                }

                return true;
            });

            return ret;
        }

        Service.prototype.isConfigurable = function (widgetObj) {
            return this.configurableWidget(widgetObj);
        }

        Service.prototype.configurableWidget = function (widgetObj) {
            var self = this,
                result = null;

            if (widgetObj && widgetObj.isKindOf("BaseSketchWidget")) {
                if (widgetObj.$element && widgetObj.$element.hasClass("widgetContainer")) {
                    var $parent = widgetObj.$element.parent();
                    if ($parent.length) {
                        result = self.configurableWidget($parent.data("widgetObject"));
                    }
                } else if (widgetObj.isKindOf("RepoSketchWidget")) {
                    if (!_.isEmpty(_.omit(widgetObj.widgetSpec && widgetObj.widgetSpec.configuration || {}, "state")))
                        result = widgetObj;
                }
            }

            return result;
        }

        Service.prototype.anchorElement = function (element) {
            var $element;

            if (element.jquery) {
                $element = element;
            } else if (typeof element === "string" || angular.isElement(element)) {
                $element = $(element);
            }

            var anchor = $element.attr($inject.angularConstants.anchorAttr);
            if (anchor) {
                $element.children("[ui-sketch-widget]").each(function (i, childElement) {
                    var $child = $(childElement),
                        widgetObj = $child.data("widgetObject");

                    widgetObj.anchor = anchor;
                });
            }
        }

        Service.prototype.disposeElement = function (element) {
            var $element;

            if (element.jquery) {
                $element = element;
            } else if (typeof element === "string" || angular.isElement(element)) {
                $element = $(element);
            }

            $element.children("[ui-sketch-widget]").each(function (i, childElement) {
                var $child = $(childElement),
                    widgetObj = $child.data("widgetObject");

                widgetObj.dispose();
            });
            $element.remove();
        }

        Service.prototype.loadProject = function (dbObject) {
            var self = this;

            if (self.$rootScope.loadedProject) {
                self.$rootScope.loadedProject.unload();
                self.$rootScope.loadedProject.populate(dbObject);
            } else {
                self.$rootScope.loadedProject = new Project(dbObject);
            }

            return this.uiUtilService.chain(
                [
                    function () {
                        return self.$rootScope.loadedProject.loadDependencies();
                    },
                    function () {
                        return self.$rootScope.loadedProject.loadSketch();
                    },
                    function () {
                        self.$rootScope.$broadcast(self.angularEventTypes.switchProjectEvent, self.$rootScope.loadedProject);

                        return self.$rootScope.loadedProject.tryLock(self.$rootScope.loginUser._id);
                    }
                ]
            );
        }

        Service.prototype.createEditor = function (holder, markdown) {
            var $textHolder;

            if (holder.jquery) {
                $textHolder = holder;
            } else if (typeof holder === "string" || angular.isElement(holder)) {
                $textHolder = $(holder);
            }

            if ($textHolder) {
                var $text = $textHolder.children(":first-child"),
                    id = $text.attr("id"),
                    editor;

                if (id) {
                    editor = $textHolder.data("editor") || editormd.inline(id);
                    editor.setMarkdown(markdown || "");
                    $textHolder.data("editor", editor);

                    $textHolder.on("editormd.hide", function (event, data) {
                        var $this = $(this),
                            widgetObject = $this.data("widgetObject");

                        if (widgetObject) {
                            widgetObject.markdown = data.markdown;
                            widgetObject.setHtml(data.html);
                            $this.removeData("widgetObject");
                        }
                    });
                }

                return editor;
            }
        }

        return function (appModule) {
            appModule.
                config(["$provide", function ($provide) {
                    $provide.service('uiService', Service);
                }]);
        };
    }
)
;