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
      class Error < ::Protobuf::Message
        class Type < ::Protobuf::Enum
          define :UnknownError, 0
          define :InvalidRecord, 3
          define :InvalidRequest, 4
          define :InvalidResponse, 5
          define :InvalidProtobufMessage, 6
          define :InvalidJSON, 7
          define :FailedToOpenEnvelope, 8
          define :InvalidStateTransition, 9
          define :ResourceConflict, 11
          define :ResourceExists, 12
          define :ResourceNotFound, 13
          define :RouterError, 14
          define :ActualLRPCannotBeClaimed, 15
          define :ActualLRPCannotBeStarted, 16
          define :ActualLRPCannotBeCrashed, 17
          define :ActualLRPCannotBeFailed, 18
          define :ActualLRPCannotBeRemoved, 19
          define :ActualLRPCannotBeUnclaimed, 21
          define :ActualLRPCannotBeEvacuated, 22
          define :RunningOnDifferentCell, 24
          define :GUIDGeneration, 26
          define :Deserialize, 27
          define :Deadlock, 28
          define :Unrecoverable, 29
          define :LockCollision, 30
          define :Timeout, 31
        end

      end



      ##
      # File Options
      #
      set_option :".gogoproto.goproto_enum_prefix_all", true
      set_option :".gogoproto.equal_all", false


      ##
      # Message Fields
      #
      class Error
        optional ::Diego::Bbs::Models::Error::Type, :type, 1, :".gogoproto.nullable" => false
        optional :string, :message, 2, :".gogoproto.nullable" => false
      end

    end

  end

end

