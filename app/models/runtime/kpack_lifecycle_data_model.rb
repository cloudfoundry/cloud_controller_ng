require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class KpackLifecycleDataModel < Sequel::Model(:kpack_lifecycle_data)
    include Serializer

    many_to_one :app,
                class: '::VCAP::CloudController::AppModel',
                key: :app_guid,
                primary_key: :guid,
                without_guid_generation: true

    many_to_one :droplet,
                class: '::VCAP::CloudController::DropletModel',
                key: :droplet_guid,
                primary_key: :guid,
                without_guid_generation: true

    many_to_one :build,
                class: '::VCAP::CloudController::BuildModel',
                key: :build_guid,
                primary_key: :guid,
                without_guid_generation: true

    # if this gets any thicker, we should model it properly in its own table
    serializes_via_json :buildpacks

    def using_custom_buildpack?
      false
    end

    def buildpack_models
      return []
    end

    def first_custom_buildpack_url
      return nil
    end

    # def buildpacks=(new_buildpacks) end

    def to_hash
      {
        buildpacks: buildpacks
      }
    end

    def stack
      nil
    end

    def stack=(new_value) end
  end
end
