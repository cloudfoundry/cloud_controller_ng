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
      class ConvergeLRPsResponse < ::Protobuf::Message; end


      ##
      # Message Fields
      #
      class ConvergeLRPsResponse
        optional ::Diego::Bbs::Models::Error, :error, 1
      end

    end

  end

end

