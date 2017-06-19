# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'modification_tag.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class ActualLRPGroup < ::Protobuf::Message; end
      class PortMapping < ::Protobuf::Message; end
      class ActualLRPKey < ::Protobuf::Message; end
      class ActualLRPInstanceKey < ::Protobuf::Message; end
      class ActualLRPNetInfo < ::Protobuf::Message; end
      class ActualLRP < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class ActualLRPGroup
        optional ::Diego::Bbs::Models::ActualLRP, :instance, 1
        optional ::Diego::Bbs::Models::ActualLRP, :evacuating, 2
      end

      class PortMapping
        optional :uint32, :container_port, 1
        optional :uint32, :host_port, 2
      end

      class ActualLRPKey
        optional :string, :process_guid, 1
        optional :int32, :index, 2
        optional :string, :domain, 3
      end

      class ActualLRPInstanceKey
        optional :string, :instance_guid, 1
        optional :string, :cell_id, 2
      end

      class ActualLRPNetInfo
        optional :string, :address, 1
        repeated ::Diego::Bbs::Models::PortMapping, :ports, 2
        optional :string, :instance_address, 3
      end

      class ActualLRP
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2
        optional ::Diego::Bbs::Models::ActualLRPNetInfo, :actual_lrp_net_info, 3
        optional :int32, :crash_count, 4
        optional :string, :crash_reason, 5
        optional :string, :state, 6
        optional :string, :placement_error, 7
        optional :int64, :since, 8
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 9
      end

    end

  end

end

