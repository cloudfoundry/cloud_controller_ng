## Generated from actual_lrp.proto for models
require "beefcake"

require_relative 'modification_tag.pb'


module Diego
  module Bbs
    module Models

      class ActualLRPGroup
        include Beefcake::Message
      end

      class PortMapping
        include Beefcake::Message
      end

      class ActualLRPKey
        include Beefcake::Message
      end

      class ActualLRPInstanceKey
        include Beefcake::Message
      end

      class ActualLRPNetInfo
        include Beefcake::Message
      end

      class ActualLRP
        include Beefcake::Message
      end

      class ActualLRPGroup
        optional :instance, ActualLRP, 1
        optional :evacuating, ActualLRP, 2
      end

      class PortMapping
        optional :container_port, :uint32, 1
        optional :host_port, :uint32, 2
      end

      class ActualLRPKey
        optional :process_guid, :string, 1
        optional :index, :int32, 2
        optional :domain, :string, 3
      end

      class ActualLRPInstanceKey
        optional :instance_guid, :string, 1
        optional :cell_id, :string, 2
      end

      class ActualLRPNetInfo
        optional :address, :string, 1
        repeated :ports, PortMapping, 2
      end

      class ActualLRP
        optional :actual_lrp_key, ActualLRPKey, 1
        optional :actual_lrp_instance_key, ActualLRPInstanceKey, 2
        optional :actual_lrp_net_info, ActualLRPNetInfo, 3
        optional :crash_count, :int32, 4
        optional :crash_reason, :string, 5
        optional :state, :string, 6
        optional :placement_error, :string, 7
        optional :since, :int64, 8
        optional :modification_tag, ModificationTag, 9
      end
    end
  end
end
