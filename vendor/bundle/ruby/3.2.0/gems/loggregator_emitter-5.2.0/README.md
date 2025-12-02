# Loggregator Emitter 

[![Build Status](https://travis-ci.org/cloudfoundry/loggregator_emitter.svg?branch=master)](https://travis-ci.org/cloudfoundry/loggregator_emitter) [![Coverage Status](https://coveralls.io/repos/cloudfoundry/loggregator_emitter/badge.svg?branch=master)](https://coveralls.io/r/cloudfoundry/loggregator_emitter?branch=master) [![Gem Version](https://badge.fury.io/rb/loggregator_emitter.svg)](http://badge.fury.io/rb/loggregator_emitter)

### About

This gem provides an API to emit messages to the loggregator agent from Ruby applications.

Create an emitter object with the loggregator router host and port, an origin, and a source name of the emitter.

Call emit() or emit_error() on this emitter with the application GUID and the message string.

##### A valid source name is any 3 character string.   Some common component sources are:

    API (Cloud Controller)
    RTR (Go Router)
    UAA
    DEA
    APP (Warden container)
    LGR (Loggregator)

### Setup

    Add the loggregator_emitter gem to your gemfile.

    gem "loggregator_emitter"

### Sample Workflow

    require "loggregator_emitter"

    emitter = LoggregatorEmitter::Emitter.new("10.10.10.16:38452", "origin", API")

    app_guid = "a8977cb6-3365-4be1-907e-0c878b3a4c6b" # The GUID(UUID) for the user's application

    emitter.emit(app_guid, message) # Emits messages with a message type of OUT

    emitter.emit(app_guid, message, {"key" => "value"}) # Emits messages with tags

    emitter.emit_error(app_guid, error_message) # Emits messages with a message type of ERR

### Regenerating Protobuf library

BEEFCAKE_NAMESPACE=Sonde protoc --beefcake_out lib/sonde -I ~/workspace/cf-release/src/loggregator/src/github.com/cloudfoundry/sonde-go/definitions/events ~/workspace/cf-release/src/loggregator/src/github.com/cloudfoundry/sonde-go/definitions/events/envelope.proto

### Versioning

This gem is versioned using [semantic versioning](http://semver.org/).
