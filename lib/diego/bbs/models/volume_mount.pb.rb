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
      # Enum Classes
      #
      class DeprecatedBindMountMode < ::Protobuf::Enum
        define :RO, 0
        define :RW, 1
      end


      ##
      # Message Classes
      #
      class SharedDevice < ::Protobuf::Message; end
      class VolumeMount < ::Protobuf::Message; end
      class VolumePlacement < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class SharedDevice
        optional :string, :volume_id, 1
        optional :string, :mount_config, 2
      end

      class VolumeMount
        optional :string, :deprecated_volume_id, 2, :deprecated => true
        optional ::Diego::Bbs::Models::DeprecatedBindMountMode, :deprecated_mode, 4, :deprecated => true
        optional :bytes, :deprecated_config, 5, :deprecated => true
        optional :string, :driver, 1
        optional :string, :container_dir, 3
        optional :string, :mode, 6
        optional ::Diego::Bbs::Models::SharedDevice, :shared, 7
      end

      class VolumePlacement
        repeated :string, :driver_names, 1
      end

    end

  end

end

