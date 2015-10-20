module VCAP::CloudController
  class BuildpackLifecycleDataModel < Sequel::Model(:buildpack_lifecycle_data)
    LIFECYCLE_TYPE = 'buildpack'.freeze

    many_to_one :droplet,
      class: '::VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :app,
      class: '::VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    def to_hash
      { buildpack: buildpack, stack: stack }
    end

    def validate
      return unless app_guid && droplet_guid
      errors.add(:lifecycle_data, 'Cannot be associated with both a droplet and an app')
    end
  end
end
