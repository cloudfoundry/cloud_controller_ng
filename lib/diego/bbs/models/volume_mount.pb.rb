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

