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
      class ModificationTag < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class ModificationTag
        optional :string, :epoch, 1
        optional :uint32, :index, 2
      end

    end

  end

end

