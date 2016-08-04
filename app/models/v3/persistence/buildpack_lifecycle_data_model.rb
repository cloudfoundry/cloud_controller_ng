require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackLifecycleDataModel < Sequel::Model(:buildpack_lifecycle_data)
    LIFECYCLE_TYPE = Lifecycles::BUILDPACK

    encrypt :buildpack, salt: :salt, column: :encrypted_buildpack

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

    def buildpack_with_serialization=(buildpack_name)
      self.buildpack_without_serialization = buildpack_name
    end
    alias_method_chain :buildpack=, 'serialization'

    def buildpack_with_serialization
      buildpack_without_serialization
    end
    alias_method_chain :buildpack, 'serialization'

    def to_hash
      { buildpack: obfuscate_buildpack(buildpack), stack: stack }
    end

    def validate
      return unless app_guid && droplet_guid
      errors.add(:lifecycle_data, 'Cannot be associated with both a droplet and an app')
    end

    private

    def obfuscate_buildpack(buildpack)
      return if buildpack.nil?

      parsed_url = Addressable::URI.parse(buildpack)

      if parsed_url.user
        parsed_url.user = '***'
        parsed_url.password = '***'
      end

      parsed_url.to_s
    end
  end
end
