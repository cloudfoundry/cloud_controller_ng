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
    class LogMessage < ::Protobuf::Message
      class MessageType < ::Protobuf::Enum
        define :OUT, 1
        define :ERR, 2
      end
    end

    ##
    # Message Fields
    #
    class LogMessage
      required :bytes, :message, 1
      required ::TrafficController::Models::LogMessage::MessageType, :message_type, 2
      required :int64, :timestamp, 3
      optional :string, :app_id, 4
      optional :string, :source_type, 5
      optional :string, :source_instance, 6
    end
  end
end
