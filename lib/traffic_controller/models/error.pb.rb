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
    class Error < ::Protobuf::Message; end

    ##
    # Message Fields
    #
    class Error
      required :string, :source, 1
      required :int32, :code, 2
      required :string, :message, 3
    end
  end
end
