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
      class Error < ::Protobuf::Message
        class Type < ::Protobuf::Enum
          define :UnknownError, 0
          define :InvalidDomain, 1
          define :UnkownVersion, 2
          define :InvalidRecord, 3
          define :InvalidRequest, 4
          define :InvalidResponse, 5
          define :InvalidProtobufMessage, 6
          define :InvalidJSON, 7
          define :FailedToOpenEnvelope, 8
          define :InvalidStateTransition, 9
          define :Unauthorized, 10
          define :ResourceConflict, 11
          define :ResourceExists, 12
          define :ResourceNotFound, 13
          define :RouterError, 14
          define :ActualLRPCannotBeClaimed, 15
          define :ActualLRPCannotBeStarted, 16
          define :ActualLRPCannotBeCrashed, 17
          define :ActualLRPCannotBeFailed, 18
          define :ActualLRPCannotBeRemoved, 19
          define :ActualLRPCannotBeStopped, 20
          define :ActualLRPCannotBeUnclaimed, 21
          define :ActualLRPCannotBeEvacuated, 22
          define :DesiredLRPCannotBeUpdated, 23
          define :RunningOnDifferentCell, 24
          define :DesiredLRPSchedulingInfoCannotBeUpdated, 25
          define :GUIDGeneration, 26
          define :Deserialize, 27
          define :Deadlock, 28
          define :Unrecoverable, 29
          define :LockCollision, 30
        end

      end



      ##
      # Message Fields
      #
      class Error
        optional ::Diego::Bbs::Models::Error::Type, :type, 1
        optional :string, :message, 2
      end

    end

  end

end

