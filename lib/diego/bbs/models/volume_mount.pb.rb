## Generated from volume_mount.proto for models
require "beefcake"

module Diego
  module Bbs
    module Models

      module DeprecatedBindMountMode
        RO = 0
        RW = 1
      end

      class SharedDevice
        include Beefcake::Message
      end

      class VolumeMount
        include Beefcake::Message
      end

      class VolumePlacement
        include Beefcake::Message
      end

      class SharedDevice
        optional :volume_id, :string, 1
        optional :mount_config, :string, 2
      end

      class VolumeMount
        optional :deprecated_volume_id, :string, 2
        optional :deprecated_mode, DeprecatedBindMountMode, 4
        optional :deprecated_config, :bytes, 5
        optional :driver, :string, 1
        optional :container_dir, :string, 3
        optional :mode, :string, 6
        optional :shared, SharedDevice, 7
      end

      class VolumePlacement
        repeated :driver_names, :string, 1
      end
    end
  end
end
