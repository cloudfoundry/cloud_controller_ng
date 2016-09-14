require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackLifecycleDataModel < Sequel::Model(:buildpack_lifecycle_data)
    LIFECYCLE_TYPE = Lifecycles::BUILDPACK

    encrypt :buildpack_url, salt: :encrypted_buildpack_url_salt, column: :encrypted_buildpack_url

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

    def buildpack=(buildpack)
      self.buildpack_url = nil
      self.admin_buildpack_name = nil

      if buildpack.is_uri?
        self.buildpack_url = buildpack
      else
        self.admin_buildpack_name = buildpack
      end
    end

    def buildpack
      return self.admin_buildpack_name if self.admin_buildpack_name.present?
      self.buildpack_url
    end

    def to_hash
      { buildpack: CloudController::UrlSecretObfuscator.obfuscate(buildpack), stack: stack }
    end

    def validate
      return unless app_guid && droplet_guid
      errors.add(:lifecycle_data, 'Cannot be associated with both a droplet and an app')
    end
  end
end
