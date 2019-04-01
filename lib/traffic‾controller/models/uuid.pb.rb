# encoding: utf-8

##
# This file is auto-generated. DO NOT EDIT!
#
require 'protobuf/message'

module TrafficController
  module Models
    ##
    # Message Classes
    #
    class UUID < ::Protobuf::Message; end

    ##
    # Message Fields
    #
    class UUID
      required :uint64, :low, 1
      required :uint64, :high, 2
    end
  end
end
