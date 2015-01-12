module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PENDING_STATE  = 'PROCESSING_UPLOAD'
    READY_STATE    = 'READY'
    FAILED_STATE   = 'FAILED'
    CREATED_STATE  = 'AWAITING_UPLOAD'
    PACKAGE_STATES = [CREATED_STATE, PENDING_STATE, READY_STATE, FAILED_STATE].map(&:freeze).freeze

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
    end
  end
end
