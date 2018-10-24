# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'modification_tag.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class ActualLRPGroup < ::Protobuf::Message; end
      class PortMapping < ::Protobuf::Message; end
      class ActualLRPKey < ::Protobuf::Message; end
      class ActualLRPInstanceKey < ::Protobuf::Message; end
      class ActualLRPNetInfo < ::Protobuf::Message; end
      class ActualLRP < ::Protobuf::Message
        class Presence < ::Protobuf::Enum
          define :Ordinary, 0
          define :Evacuating, 1
          define :Suspect, 2
        end

      end



      ##
      # File Options
      #
      set_option :".gogoproto.goproto_enum_prefix_all", true


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
        optional :uint32, :container_tls_proxy_port, 3, :".gogoproto.jsontag" => "container_tls_proxy_port,omitempty"
        optional :uint32, :host_tls_proxy_port, 4, :".gogoproto.jsontag" => "host_tls_proxy_port,omitempty"
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
        repeated ::Diego::Bbs::Models::PortMapping, :ports, 2, :".gogoproto.jsontag" => "ports"
        optional :string, :instance_address, 3, :".gogoproto.jsontag" => "instance_address,omitempty"
      end

      class ActualLRP
        optional ::Diego::Bbs::Models::ActualLRPKey, :actual_lrp_key, 1, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional ::Diego::Bbs::Models::ActualLRPInstanceKey, :actual_lrp_instance_key, 2, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional ::Diego::Bbs::Models::ActualLRPNetInfo, :actual_lrp_net_info, 3, :".gogoproto.nullable" => false, :".gogoproto.embed" => true, :".gogoproto.jsontag" => ""
        optional :int32, :crash_count, 4
        optional :string, :crash_reason, 5, :".gogoproto.jsontag" => "crash_reason,omitempty"
        optional :string, :state, 6
        optional :string, :placement_error, 7, :".gogoproto.jsontag" => "placement_error,omitempty"
        optional :int64, :since, 8
        optional ::Diego::Bbs::Models::ModificationTag, :modification_tag, 9, :".gogoproto.nullable" => false
        optional ::Diego::Bbs::Models::ActualLRP::Presence, :presence, 10
      end

    end

  end

end

