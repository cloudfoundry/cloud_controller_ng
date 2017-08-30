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
      class PortRange < ::Protobuf::Message; end
      class ICMPInfo < ::Protobuf::Message; end
      class SecurityGroupRule < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class PortRange
        optional :uint32, :start, 1
        optional :uint32, :end, 2
      end

      class ICMPInfo
        optional :int32, :type, 1
        optional :int32, :code, 2
      end

      class SecurityGroupRule
        optional :string, :protocol, 1
        repeated :string, :destinations, 2
        repeated :uint32, :ports, 3
        optional ::Diego::Bbs::Models::PortRange, :port_range, 4
        optional ::Diego::Bbs::Models::ICMPInfo, :icmp_info, 5
        optional :bool, :log, 6
        repeated :string, :annotations, 7
      end

    end

  end

end

