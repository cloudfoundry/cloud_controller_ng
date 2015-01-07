module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PACKAGE_STATES = %w[PENDING READY FAILED].map(&:freeze).freeze

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
    end
  end
end
