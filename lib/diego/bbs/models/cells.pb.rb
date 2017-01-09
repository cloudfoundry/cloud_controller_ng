# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'


##
# Imports
#
require 'github.com/gogo/protobuf/gogoproto/gogo.pb'
require 'error.pb'

module Diego
  module Bbs
    module Models

      ##
      # Message Classes
      #
      class CellCapacity < ::Protobuf::Message; end
      class CellPresence < ::Protobuf::Message; end
      class Provider < ::Protobuf::Message; end
      class CellsResponse < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class CellCapacity
        optional :int32, :memory_mb, 1
        optional :int32, :disk_mb, 2
        optional :int32, :containers, 3
      end

      class CellPresence
        optional :string, :cell_id, 1
        optional :string, :rep_address, 2
        optional :string, :zone, 3
        optional ::Diego::Bbs::Models::CellCapacity, :capacity, 4
        repeated ::Diego::Bbs::Models::Provider, :rootfs_providers, 5
        repeated :string, :placement_tags, 6
        repeated :string, :optional_placement_tags, 7
        optional :string, :rep_url, 8
      end

      class Provider
        optional :string, :name, 1
        repeated :string, :properties, 2
      end

      class CellsResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
        repeated ::Diego::Bbs::Models::CellPresence, :cells, 2
      end

    end

  end

end

