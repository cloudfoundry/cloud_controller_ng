require 'diego/bbs/models/error_pb'

module Diego::Bbs::ErrorTypes
  class << self
    def lookup_error_type(error_type)
      ::Diego::Bbs::Models::Error::Type.lookup(error_type)
    end
  end

  UnknownError               = lookup_error_type(::Diego::Bbs::Models::Error::Type::UnknownError)
  InvalidRecord              = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidRecord)
  InvalidRequest             = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidRequest)
  InvalidResponse            = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidResponse)
  InvalidProtobufMessage     = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidProtobufMessage)
  InvalidJSON                = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidJSON)
  FailedToOpenEnvelope       = lookup_error_type(::Diego::Bbs::Models::Error::Type::FailedToOpenEnvelope)
  InvalidStateTransition     = lookup_error_type(::Diego::Bbs::Models::Error::Type::InvalidStateTransition)
  ResourceConflict           = lookup_error_type(::Diego::Bbs::Models::Error::Type::ResourceConflict)
  ResourceExists             = lookup_error_type(::Diego::Bbs::Models::Error::Type::ResourceExists)
  ResourceNotFound           = lookup_error_type(::Diego::Bbs::Models::Error::Type::ResourceNotFound)
  RouterError                = lookup_error_type(::Diego::Bbs::Models::Error::Type::RouterError)
  ActualLRPCannotBeClaimed   = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeClaimed)
  ActualLRPCannotBeStarted   = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeStarted)
  ActualLRPCannotBeCrashed   = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeCrashed)
  ActualLRPCannotBeFailed    = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeFailed)
  ActualLRPCannotBeRemoved   = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeRemoved)
  ActualLRPCannotBeUnclaimed = lookup_error_type(::Diego::Bbs::Models::Error::Type::ActualLRPCannotBeUnclaimed)
  RunningOnDifferentCell     = lookup_error_type(::Diego::Bbs::Models::Error::Type::RunningOnDifferentCell)
  GUIDGeneration             = lookup_error_type(::Diego::Bbs::Models::Error::Type::GUIDGeneration)
  Deserialize                = lookup_error_type(::Diego::Bbs::Models::Error::Type::Deserialize)
  Deadlock                   = lookup_error_type(::Diego::Bbs::Models::Error::Type::Deadlock)
  Unrecoverable              = lookup_error_type(::Diego::Bbs::Models::Error::Type::Unrecoverable)
  LockCollision              = lookup_error_type(::Diego::Bbs::Models::Error::Type::LockCollision)
  Timeout                    = lookup_error_type(::Diego::Bbs::Models::Error::Type::Timeout)
end
