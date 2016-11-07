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
      class EnvironmentVariable < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class EnvironmentVariable
        optional :string, :name, 1
        optional :string, :value, 2
      end

    end

  end

end

