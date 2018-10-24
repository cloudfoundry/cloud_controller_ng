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
      class Network < ::Protobuf::Message
      end



      ##
      # File Options
      #
      set_option :".gogoproto.goproto_enum_prefix_all", true


      ##
      # Message Fields
      #
      class Network
        map :string, :string, :properties, 1, :".gogoproto.jsontag" => "properties,omitempty"
      end

    end

  end

end

