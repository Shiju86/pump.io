# scrubber-test.js
#
# Test the scrubber module
#
# Copyright 2012, StatusNet Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
assert = require("assert")
vows = require("vows")
_ = require("underscore")
DANGEROUS = "This is a <script>alert('Boo!')</script> dangerous string."
HARMLESS = "This is a harmless string."
vows.describe("scrubber module interface").addBatch("When we require the scrubber module":
  topic: ->
    require "../lib/scrubber"

  "it works": (stamper) ->
    assert.isObject stamper

  "and we get its Scrubber export":
    topic: (scrubber) ->
      scrubber.Scrubber

    "it exists": (Scrubber) ->
      assert.isObject Scrubber

    "it has a scrub() method": (Scrubber) ->
      assert.isFunction Scrubber.scrub

    "it has a scrubActivity() method": (Scrubber) ->
      assert.isFunction Scrubber.scrubActivity

    "it has a scrubObject() method": (Scrubber) ->
      assert.isFunction Scrubber.scrubObject

    "and we scrub some dangerous text":
      topic: (Scrubber) ->
        Scrubber.scrub DANGEROUS

      "it works": (result) ->
        assert.isString result
        assert.equal result.indexOf("<script>"), -1

    "and we scrub some innocuous text":
      topic: (Scrubber) ->
        Scrubber.scrub HARMLESS

      "it works": (result) ->
        assert.isString result
        assert.equal result, HARMLESS

    "and we scrub an object with innocuous content":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          content: HARMLESS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isString result.content
        assert.equal result.content, HARMLESS

    "and we scrub an object with dangerous content":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          content: DANGEROUS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isString result.content
        assert.equal result.content.indexOf("<script>"), -1

    "and we scrub an object with innocuous summary":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          summary: HARMLESS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isString result.summary
        assert.equal result.summary, HARMLESS

    "and we scrub an object with dangerous summary":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          summary: DANGEROUS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isString result.summary
        assert.equal result.summary.indexOf("<script>"), -1

    "and we scrub an object with innocuous author":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          author:
            objectType: "person"
            summary: HARMLESS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.author
        assert.isString result.author.summary
        assert.equal result.author.summary, HARMLESS

    "and we scrub an object with a dangerous author":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          author:
            objectType: "person"
            summary: DANGEROUS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.author
        assert.isString result.author.summary
        assert.equal result.author.summary.indexOf("<script>"), -1

    "and we scrub an object with innocuous location":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          location:
            objectType: "place"
            summary: HARMLESS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.location
        assert.isString result.location.summary
        assert.equal result.location.summary, HARMLESS

    "and we scrub an object with a dangerous location":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          location:
            objectType: "place"
            summary: DANGEROUS

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.location
        assert.isString result.location.summary
        assert.equal result.location.summary.indexOf("<script>"), -1

    "and we scrub an object with innocuous attachments":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          attachments: [
            objectType: "image"
            summary: HARMLESS
          ,
            objectType: "image"
            summary: HARMLESS
          ]

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isArray result.attachments
        assert.lengthOf result.attachments, 2
        assert.isObject result.attachments[0]
        assert.isObject result.attachments[1]
        assert.isString result.attachments[0].summary
        assert.isString result.attachments[1].summary
        assert.equal result.attachments[0].summary, HARMLESS
        assert.equal result.attachments[1].summary, HARMLESS

    "and we scrub an object with dangerous attachments":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          attachments: [
            objectType: "image"
            summary: DANGEROUS
          ,
            objectType: "image"
            summary: DANGEROUS
          ]

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isArray result.attachments
        assert.lengthOf result.attachments, 2
        assert.isObject result.attachments[0]
        assert.isObject result.attachments[1]
        assert.isString result.attachments[0].summary
        assert.isString result.attachments[1].summary
        assert.equal result.attachments[0].summary.indexOf("<script>"), -1
        assert.equal result.attachments[1].summary.indexOf("<script>"), -1

    "and we scrub an object with innocuous tags":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          tags: [
            objectType: "image"
            summary: HARMLESS
          ,
            objectType: "image"
            summary: HARMLESS
          ]

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isArray result.tags
        assert.lengthOf result.tags, 2
        assert.isObject result.tags[0]
        assert.isObject result.tags[1]
        assert.isString result.tags[0].summary
        assert.isString result.tags[1].summary
        assert.equal result.tags[0].summary, HARMLESS
        assert.equal result.tags[1].summary, HARMLESS

    "and we scrub an object with dangerous tags":
      topic: (Scrubber) ->
        obj =
          objectType: "note"
          tags: [
            objectType: "image"
            summary: DANGEROUS
          ,
            objectType: "image"
            summary: DANGEROUS
          ]

        Scrubber.scrubObject obj

      "it works": (result) ->
        assert.isObject result
        assert.isArray result.tags
        assert.lengthOf result.tags, 2
        assert.isObject result.tags[0]
        assert.isObject result.tags[1]
        assert.isString result.tags[0].summary
        assert.isString result.tags[1].summary
        assert.equal result.tags[0].summary.indexOf("<script>"), -1
        assert.equal result.tags[1].summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous content":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: HARMLESS
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isString result.content
        assert.equal result.content, HARMLESS

    "and we scrub an activity with dangerous content":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: DANGEROUS
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isString result.content
        assert.equal result.content.indexOf("<script>"), -1

    "and we scrub an activity with innocuous actor":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"
            summary: HARMLESS

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.actor
        assert.isString result.actor.summary
        assert.equal result.actor.summary, HARMLESS

    "and we scrub an activity with dangerous actor":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"
            summary: DANGEROUS

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.actor
        assert.isString result.actor.summary
        assert.equal result.actor.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous object":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"
            summary: HARMLESS

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.object
        assert.isString result.object.content
        assert.equal result.object.content, HARMLESS

    "and we scrub an activity with dangerous object":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.object
        assert.isString result.object.content
        assert.equal result.object.content.indexOf("<script>"), -1

    "and we scrub an activity with innocuous target":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          target:
            objectType: "collection"
            summary: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.target
        assert.isString result.target.summary
        assert.equal result.target.summary, HARMLESS

    "and we scrub an activity with dangerous target":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          target:
            objectType: "collection"
            summary: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.target
        assert.isString result.target.summary
        assert.equal result.target.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous generator":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          generator:
            objectType: "application"
            summary: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.generator
        assert.isString result.generator.summary
        assert.equal result.generator.summary, HARMLESS

    "and we scrub an activity with dangerous generator":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          generator:
            objectType: "application"
            summary: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.generator
        assert.isString result.generator.summary
        assert.equal result.generator.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous provider":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          provider:
            objectType: "application"
            summary: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.provider
        assert.isString result.provider.summary
        assert.equal result.provider.summary, HARMLESS

    "and we scrub an activity with dangerous provider":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          provider:
            objectType: "application"
            summary: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.provider
        assert.isString result.provider.summary
        assert.equal result.provider.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous context":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          context:
            objectType: "event"
            summary: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.context
        assert.isString result.context.summary
        assert.equal result.context.summary, HARMLESS

    "and we scrub an activity with dangerous context":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          context:
            objectType: "event"
            summary: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.context
        assert.isString result.context.summary
        assert.equal result.context.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous source":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          source:
            objectType: "collection"
            summary: HARMLESS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.source
        assert.isString result.source.summary
        assert.equal result.source.summary, HARMLESS

    "and we scrub an activity with dangerous source":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          source:
            objectType: "collection"
            summary: DANGEROUS

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.source
        assert.isString result.source.summary
        assert.equal result.source.summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous 'to' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          to: [
            objectType: "person"
            summary: HARMLESS
          ,
            objectType: "person"
            summary: HARMLESS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.to
        assert.lengthOf result.to, 2
        assert.isObject result.to[0]
        assert.isObject result.to[1]
        assert.isString result.to[0].summary
        assert.isString result.to[1].summary
        assert.equal result.to[0].summary, HARMLESS
        assert.equal result.to[1].summary, HARMLESS

    "and we scrub an activity with dangerous 'to' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          to: [
            objectType: "person"
            summary: DANGEROUS
          ,
            objectType: "person"
            summary: DANGEROUS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.to
        assert.lengthOf result.to, 2
        assert.isObject result.to[0]
        assert.isObject result.to[1]
        assert.isString result.to[0].summary
        assert.isString result.to[1].summary
        assert.equal result.to[0].summary.indexOf("<script>"), -1
        assert.equal result.to[1].summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous 'cc' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          cc: [
            objectType: "person"
            summary: HARMLESS
          ,
            objectType: "person"
            summary: HARMLESS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.cc
        assert.lengthOf result.cc, 2
        assert.isObject result.cc[0]
        assert.isObject result.cc[1]
        assert.isString result.cc[0].summary
        assert.isString result.cc[1].summary
        assert.equal result.cc[0].summary, HARMLESS
        assert.equal result.cc[1].summary, HARMLESS

    "and we scrub an activity with dangerous 'cc' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          cc: [
            objectType: "person"
            summary: DANGEROUS
          ,
            objectType: "person"
            summary: DANGEROUS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.cc
        assert.lengthOf result.cc, 2
        assert.isObject result.cc[0]
        assert.isObject result.cc[1]
        assert.isString result.cc[0].summary
        assert.isString result.cc[1].summary
        assert.equal result.cc[0].summary.indexOf("<script>"), -1
        assert.equal result.cc[1].summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous 'bto' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          bto: [
            objectType: "person"
            summary: HARMLESS
          ,
            objectType: "person"
            summary: HARMLESS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.bto
        assert.lengthOf result.bto, 2
        assert.isObject result.bto[0]
        assert.isObject result.bto[1]
        assert.isString result.bto[0].summary
        assert.isString result.bto[1].summary
        assert.equal result.bto[0].summary, HARMLESS
        assert.equal result.bto[1].summary, HARMLESS

    "and we scrub an activity with dangerous 'bto' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          bto: [
            objectType: "person"
            summary: DANGEROUS
          ,
            objectType: "person"
            summary: DANGEROUS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.bto
        assert.lengthOf result.bto, 2
        assert.isObject result.bto[0]
        assert.isObject result.bto[1]
        assert.isString result.bto[0].summary
        assert.isString result.bto[1].summary
        assert.equal result.bto[0].summary.indexOf("<script>"), -1
        assert.equal result.bto[1].summary.indexOf("<script>"), -1

    "and we scrub an activity with innocuous 'bcc' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          bcc: [
            objectType: "person"
            summary: HARMLESS
          ,
            objectType: "person"
            summary: HARMLESS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.bcc
        assert.lengthOf result.bcc, 2
        assert.isObject result.bcc[0]
        assert.isObject result.bcc[1]
        assert.isString result.bcc[0].summary
        assert.isString result.bcc[1].summary
        assert.equal result.bcc[0].summary, HARMLESS
        assert.equal result.bcc[1].summary, HARMLESS

    "and we scrub an activity with dangerous 'bcc' recipients":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

          bcc: [
            objectType: "person"
            summary: DANGEROUS
          ,
            objectType: "person"
            summary: DANGEROUS
          ]

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result
        assert.isArray result.bcc
        assert.lengthOf result.bcc, 2
        assert.isObject result.bcc[0]
        assert.isObject result.bcc[1]
        assert.isString result.bcc[0].summary
        assert.isString result.bcc[1].summary
        assert.equal result.bcc[0].summary.indexOf("<script>"), -1
        assert.equal result.bcc[1].summary.indexOf("<script>"), -1

    "and we scrub an activity with private members":
      topic: (Scrubber) ->
        act =
          _uuid: "MADEUP"
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isFalse _.has(result, "_uuid")

    "and we scrub an activity with an actor with private members":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"
            _user: true

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.actor
        assert.isFalse _.has(result.actor, "_user")

    "and we scrub an activity with an object with private members":
      topic: (Scrubber) ->
        act =
          actor:
            objectType: "person"
            displayName: "Anonymous"

          verb: "post"
          content: "Anonymous posted a note"
          object:
            objectType: "note"
            content: "Hello, world!"
            _uuid: true

        Scrubber.scrubActivity act

      "it works": (result) ->
        assert.isObject result
        assert.isObject result.object
        assert.isFalse _.has(result.object, "_uuid")
)["export"] module
