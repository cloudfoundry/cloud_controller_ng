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

    def self.user_visible(user)
      dataset.
        join(AppModel.table_name, :"#{AppModel.table_name}__guid" => :"#{DropletModel.table_name}__app_guid").
        where(AppModel.user_visibility_filter(user)).
        select_all(DropletModel.table_name)
    end

    def blobstore_key
      File.join(guid, droplet_hash) if droplet_hash
    end
  end
end
