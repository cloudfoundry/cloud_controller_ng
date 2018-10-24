# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class CheckDefinition < ::Protobuf::Message; end
      class Check < ::Protobuf::Message; end
      class TCPCheck < ::Protobuf::Message; end
      class HTTPCheck < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class CheckDefinition
        repeated ::Diego::Bbs::Models::Check, :checks, 1
        optional :string, :log_source, 2
      end

      class Check
        optional ::Diego::Bbs::Models::TCPCheck, :tcp_check, 1
        optional ::Diego::Bbs::Models::HTTPCheck, :http_check, 2
      end

      class TCPCheck
        optional :uint32, :port, 1
        optional :uint64, :connect_timeout_ms, 2
      end

      class HTTPCheck
        optional :uint32, :port, 1
        optional :uint64, :request_timeout_ms, 2
        optional :string, :path, 3
      end

    end

  end

end

