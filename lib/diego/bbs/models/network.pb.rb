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
      class Network < ::Protobuf::Message
        class PropertiesEntry < ::Protobuf::Message; end

      end



      ##
      # Message Fields
      #
      class Network
        class PropertiesEntry
          optional :string, :key, 1
          optional :string, :value, 2
        end

        repeated ::Diego::Bbs::Models::Network::PropertiesEntry, :properties, 1
      end

    end

  end

end

