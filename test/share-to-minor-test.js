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
    validActivity = actutil.validActivity,
    validFeed = actutil.validFeed;

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
                },
                "and one posts a note": {
                    topic: function(follows, creds) {
                        var callback = this.callback,
                            url = "http://localhost:4815/api/user/minnie/feed",
                            act = {
                                verb: "post",
                                object: {
                                    objectType: "note",
                                    content: "Hello, world."
                                }
                            };
                        httputil.postJSON(url, creds.minnie, act, function(err, act, response) {
                            callback(err, act);
                        });
                    },
                    "it works": function(err, act) {
                        assert.ifError(err);
                        validActivity(act);
                    },
                    "and another shares it": {
                        topic: function(postAct, follows, creds) {
                            var callback = this.callback,
                                url = "http://localhost:4815/api/user/mickey/feed",
                                act = {
                                    verb: "share",
                                    object: postAct.object
                                };
                            httputil.postJSON(url, creds.mickey, act, function(err, act, response) {
                                callback(err, act);
                            });
                        },
                        "it works": function(err, shareAct) {
                            assert.ifError(err);
                            validActivity(shareAct);
                        },
                        "and we check the inboxes of the sharer's followers": {
                            topic: function(shareAct, postAct, followActs, creds) {
                                var callback = this.callback,
                                    getInbox = function(nickname, callback) {
                                        var url = "http://localhost:4815/api/user/"+nickname+"/inbox";
                                        httputil.getJSON(url, creds[nickname], function(err, feed, response) {
                                            callback(err, feed);
                                        });
                                    };

                                Step(
                                    function() {
                                        var group = this.group();
                                        getInbox("goofy", group());
                                        getInbox("donald", group());
                                    },
                                    function(err, feeds) {
                                        callback(err, shareAct, feeds);
                                    }
                                );
                            },
                            "they contain the share activity": function(err, shareAct, feeds) {
                                assert.ifError(err);
                                validFeed(feeds[0]);
                                validFeed(feeds[1]);
                                _.each(feeds, function(feed) {
                                    assert.ok(_.some(feed.items, function(item) {
                                        return item.id == shareAct.id;
                                    }));
                                });
                            }
                        },
                        "and we check the major inbox of the sharer's follower that doesn't follow the poster": {
                            topic: function(shareAct, postAct, followActs, creds) {
                                var callback = this.callback,
                                    getMajorInbox = function(nickname, callback) {
                                        var url = "http://localhost:4815/api/user/"+nickname+"/inbox/major";
                                        httputil.getJSON(url, creds[nickname], function(err, feed, response) {
                                            callback(err, feed);
                                        });
                                    };

                                Step(
                                    function() {
                                        getMajorInbox("goofy", this);
                                    },
                                    function(err, feed) {
                                        callback(err, shareAct, feed);
                                    }
                                );
                            },
                            "it contains the share activity": function(err, shareAct, feed) {
                                assert.ifError(err);
                                validFeed(feed);
                                assert.ok(_.some(feed.items, function(item) {
                                    return item.id == shareAct.id;
                                }));
                            }
                        }
                    }
                }
            }
        }
    }
});

suite["export"](module);

