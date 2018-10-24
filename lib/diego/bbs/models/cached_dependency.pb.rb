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
      class CachedDependency < ::Protobuf::Message; end


      ##
      # File Options
      #
      set_option :".gogoproto.goproto_enum_prefix_all", true


      ##
      # Message Fields
      #
      class CachedDependency
        optional :string, :name, 1, :".gogoproto.jsontag" => "name"
        optional :string, :from, 2, :".gogoproto.jsontag" => "from"
        optional :string, :to, 3, :".gogoproto.jsontag" => "to"
        optional :string, :cache_key, 4, :".gogoproto.jsontag" => "cache_key"
        optional :string, :log_source, 5, :".gogoproto.jsontag" => "log_source"
        optional :string, :checksum_algorithm, 6, :".gogoproto.jsontag" => "checksum_algorithm,omitempty"
        optional :string, :checksum_value, 7, :".gogoproto.jsontag" => "checksum_value,omitempty"
      end

    end

  end

end

