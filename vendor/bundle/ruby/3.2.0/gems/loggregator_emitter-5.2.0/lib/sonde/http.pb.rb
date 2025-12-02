## Generated from http.proto for events
require "beefcake"

module Sonde

  module PeerType
    Client = 1
    Server = 2
  end

  module Method
    GET = 1
    POST = 2
    PUT = 3
    DELETE = 4
    HEAD = 5
    ACL = 6
    BASELINE_CONTROL = 7
    BIND = 8
    CHECKIN = 9
    CHECKOUT = 10
    CONNECT = 11
    COPY = 12
    DEBUG = 13
    LABEL = 14
    LINK = 15
    LOCK = 16
    MERGE = 17
    MKACTIVITY = 18
    MKCALENDAR = 19
    MKCOL = 20
    MKREDIRECTREF = 21
    MKWORKSPACE = 22
    MOVE = 23
    OPTIONS = 24
    ORDERPATCH = 25
    PATCH = 26
    PRI = 27
    PROPFIND = 28
    PROPPATCH = 29
    REBIND = 30
    REPORT = 31
    SEARCH = 32
    SHOWMETHOD = 33
    SPACEJUMP = 34
    TEXTSEARCH = 35
    TRACE = 36
    TRACK = 37
    UNBIND = 38
    UNCHECKOUT = 39
    UNLINK = 40
    UNLOCK = 41
    UPDATE = 42
    UPDATEREDIRECTREF = 43
    VERSION_CONTROL = 44
  end

  class HttpStartStop
    include Beefcake::Message
  end

  class HttpStartStop
    required :startTimestamp, :int64, 1
    required :stopTimestamp, :int64, 2
    required :requestId, UUID, 3
    required :peerType, PeerType, 4
    required :method, Method, 5
    required :uri, :string, 6
    required :remoteAddress, :string, 7
    required :userAgent, :string, 8
    required :statusCode, :int32, 9
    required :contentLength, :int64, 10
    optional :applicationId, UUID, 12
    optional :instanceIndex, :int32, 13
    optional :instanceId, :string, 14
    repeated :forwarded, :string, 15
  end
end
