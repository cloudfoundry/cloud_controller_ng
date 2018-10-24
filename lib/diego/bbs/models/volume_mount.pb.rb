# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'

module Diego
  module Bbs
    module Models
      ::Protobuf::Optionable.inject(self) { ::Google::Protobuf::FileOptions }

      ##
      # Message Classes
      #
      class SharedDevice < ::Protobuf::Message; end
      class VolumeMount < ::Protobuf::Message; end
      class VolumePlacement < ::Protobuf::Message; end


      ##
      # File Options
      #
      set_option :".gogoproto.goproto_enum_prefix_all", true


      ##
      # Message Fields
      #
      class SharedDevice
        optional :string, :volume_id, 1, :".gogoproto.jsontag" => "volume_id"
        optional :string, :mount_config, 2, :".gogoproto.jsontag" => "mount_config"
      end

      class VolumeMount
        optional :string, :driver, 1, :".gogoproto.jsontag" => "driver"
        optional :string, :container_dir, 3, :".gogoproto.jsontag" => "container_dir"
        optional :string, :mode, 6, :".gogoproto.jsontag" => "mode"
        optional ::Diego::Bbs::Models::SharedDevice, :shared, 7, :".gogoproto.jsontag" => "shared"
      end

      class VolumePlacement
        repeated :string, :driver_names, 1, :".gogoproto.jsontag" => "driver_names"
      end

    end

  end

end

