## Generated from error.proto for models
require "beefcake"


module Diego
  module Bbs
    module Models

      class Error
        include Beefcake::Message

        module Type
          UnknownError                            = 0
          InvalidDomain                           = 1
          UnkownVersion                           = 2
          InvalidRecord                           = 3
          InvalidRequest                          = 4
          InvalidResponse                         = 5
          InvalidProtobufMessage                  = 6
          InvalidJSON                             = 7
          FailedToOpenEnvelope                    = 8
          InvalidStateTransition                  = 9
          Unauthorized                            = 10
          ResourceConflict                        = 11
          ResourceExists                          = 12
          ResourceNotFound                        = 13
          RouterError                             = 14
          ActualLRPCannotBeClaimed                = 15
          ActualLRPCannotBeStarted                = 16
          ActualLRPCannotBeCrashed                = 17
          ActualLRPCannotBeFailed                 = 18
          ActualLRPCannotBeRemoved                = 19
          ActualLRPCannotBeStopped                = 20
          ActualLRPCannotBeUnclaimed              = 21
          ActualLRPCannotBeEvacuated              = 22
          DesiredLRPCannotBeUpdated               = 23
          RunningOnDifferentCell                  = 24
          DesiredLRPSchedulingInfoCannotBeUpdated = 25
          GUIDGeneration                          = 26
          Deserialize                             = 27
          Deadlock                                = 28
          Unrecoverable                           = 29
        end
      end

      class Error
        optional :type, Error::Type, 1
        optional :message, :string, 2
      end
    end
  end
end
