module VCAP::CloudController
  class DropletModel < Sequel::Model(:v3_droplets)
    DROPLET_STATES = [
      PENDING_STATE = 'PENDING',
      STAGING_STATE = 'STAGING',
      FAILED_STATE  = 'FAILED',
      STAGED_STATE  = 'STAGED'
    ].map(&:freeze).freeze

    def validate
      validates_includes DROPLET_STATES, :state, allow_missing: true
    end
  end
end
