# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'

##
# Imports
#
require 'uuid.pb'

module TrafficController
  module Models
    ##
    # Enum Classes
    #
    class PeerType < ::Protobuf::Enum
      define :Client, 1
      define :Server, 2
    end

    class Method < ::Protobuf::Enum
      define :GET, 1
      define :POST, 2
      define :PUT, 3
      define :DELETE, 4
      define :HEAD, 5
      define :ACL, 6
      define :BASELINE_CONTROL, 7
      define :BIND, 8
      define :CHECKIN, 9
      define :CHECKOUT, 10
      define :CONNECT, 11
      define :COPY, 12
      define :DEBUG, 13
      define :LABEL, 14
      define :LINK, 15
      define :LOCK, 16
      define :MERGE, 17
      define :MKACTIVITY, 18
      define :MKCALENDAR, 19
      define :MKCOL, 20
      define :MKREDIRECTREF, 21
      define :MKWORKSPACE, 22
      define :MOVE, 23
      define :OPTIONS, 24
      define :ORDERPATCH, 25
      define :PATCH, 26
      define :PRI, 27
      define :PROPFIND, 28
      define :PROPPATCH, 29
      define :REBIND, 30
      define :REPORT, 31
      define :SEARCH, 32
      define :SHOWMETHOD, 33
      define :SPACEJUMP, 34
      define :TEXTSEARCH, 35
      define :TRACE, 36
      define :TRACK, 37
      define :UNBIND, 38
      define :UNCHECKOUT, 39
      define :UNLINK, 40
      define :UNLOCK, 41
      define :UPDATE, 42
      define :UPDATEREDIRECTREF, 43
      define :VERSION_CONTROL, 44
    end

    ##
    # Message Classes
    #
    class HttpStartStop < ::Protobuf::Message; end

    ##
    # Message Fields
    #
    class HttpStartStop
      required :int64, :startTimestamp, 1
      required :int64, :stopTimestamp, 2
      required ::TrafficController::Models::UUID, :requestId, 3
      required ::TrafficController::Models::PeerType, :peerType, 4
      required ::TrafficController::Models::Method, :method, 5
      required :string, :uri, 6
      required :string, :remoteAddress, 7
      required :string, :userAgent, 8
      required :int32, :statusCode, 9
      required :int64, :contentLength, 10
      optional ::TrafficController::Models::UUID, :applicationId, 12
      optional :int32, :instanceIndex, 13
      optional :string, :instanceId, 14
      repeated :string, :forwarded, 15
    end
  end
end
