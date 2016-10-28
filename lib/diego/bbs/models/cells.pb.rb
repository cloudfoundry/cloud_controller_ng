## Generated from cells.proto for models
require "beefcake"

require_relative 'error.pb'


module Diego
  module Bbs
    module Models

      class CellCapacity
        include Beefcake::Message
      end

      class CellPresence
        include Beefcake::Message
      end

      class Provider
        include Beefcake::Message
      end

      class CellsResponse
        include Beefcake::Message
      end

      class CellCapacity
        optional :memory_mb, :int32, 1
        optional :disk_mb, :int32, 2
        optional :containers, :int32, 3
      end

      class CellPresence
        optional :cell_id, :string, 1
        optional :rep_address, :string, 2
        optional :zone, :string, 3
        optional :capacity, CellCapacity, 4
        repeated :rootfs_providers, Provider, 5
        repeated :placement_tags, :string, 6
        repeated :optional_placement_tags, :string, 7
      end

      class Provider
        optional :name, :string, 1
        repeated :properties, :string, 2
      end

      class CellsResponse
        optional :error, Error, 1
        repeated :cells, CellPresence, 2
      end
    end
  end
end
