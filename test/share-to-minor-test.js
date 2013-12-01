// share-to-minor-test.js
//
// Test that share activities go to the minor inbox if object is already seen
//
// Copyright 2013, E14N https://e14n.com/
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

var assert = require("assert"),
    vows = require("vows"),
    Step = require("step"),
    _ = require("underscore"),
    http = require("http"),
    version = require("../lib/version").version,
    urlparse = require("url").parse,
    httputil = require("./lib/http"),
    oauthutil = require("./lib/oauth"),
    actutil = require("./lib/activity"),
    setupApp = oauthutil.setupApp,
    newCredentials = oauthutil.newCredentials,
    validCredentials = actutil.validCredentials,
    validActivity = actutil.validActivity;

var suite = vows.describe("Share to minor test");

// A batch for testing the read-write access to the API

suite.addBatch({
    "When we set up the app": {
        topic: function() {
            setupApp(this.callback);
        },
        teardown: function(app) {
            if (app && app.close) {
                app.close();
            }
        },
        "it works": function(err, app) {
            assert.ifError(err);
        },
        "and we set up four users": {
            topic: function() {
                var callback = this.callback;
                Step(
                    function() {
                        var group = this.group();
                        newCredentials("mickey", "miska*mooska", group());
                        newCredentials("minnie", "bow*high*heels", group());
                        newCredentials("donald", "quack*quack", group());
                        newCredentials("goofy", "hyuk*hyuk*gawrsh", group());
                        newCredentials("pluto", "arf*arf*arf", group());
                    },
                    function(err, credses) {
                        if (err) throw err;
                        this(null, _.object(["mickey", "minnie", "donald", "goofy", "pluto"], credses));
                    },
                    callback
                );
            },
            "it works": function(err, creds) {
                assert.ifError(err);
                assert.isObject(creds);
                validCredentials(creds.mickey);
                validCredentials(creds.minnie);
                validCredentials(creds.donald);
                validCredentials(creds.goofy);
                validCredentials(creds.pluto);
            },
            "and they follow each other": {
                topic: function(creds) {
                    var cb = this.callback,
                        follow = function(from, to, callback) {
                            var url = "http://localhost:4815/api/user/"+from+"/feed",
                                act = {
                                    verb: "follow",
                                    object: {
                                        objectType: "person",
                                        id: creds[to].user.profile.id
                                    }
                                };
                            httputil.postJSON(url, creds[from], act, function(err, act, response) {
                                callback(err, act);
                            });
                        };

                    Step(
                        function() {
                            var group = this.group();
                            follow("mickey", "minnie", group());
                            follow("goofy", "mickey", group());
                            follow("donald", "mickey", group());
                            follow("donald", "minnie", group());
                            follow("goofy", "donald", group());
                            follow("pluto", "donald", group());
                        },
                        cb
                    );
                },
                "it works": function(err, acts) {
                    assert.ifError(err);
                    assert.lengthOf(acts, 6);
                    _.each(acts, function(act) {
                        validActivity(act);
                    });
                }
            }
        }
    }
});

suite["export"](module);

