module VCAP::CloudController
  class BuildpackLifecycleBuildpackModel < Sequel::Model(:buildpack_lifecycle_buildpacks)
    encrypt :buildpack_url, salt: :encrypted_buildpack_url_salt, column: :encrypted_buildpack_url

    many_to_one :buildpack_lifecycle_data,
      class: 'VCAP::CloudController::BuildpackLifecycleDataModel',
      primary_key: :guid,
      key: :buildpack_lifecycle_data_guid,
      without_guid_generation: true

    def name
      buildpack_url || admin_buildpack_name
    end

    def custom?
      buildpack_url.present?
    end

    def validate
      if buildpack_url.present? == admin_buildpack_name.present?
        errors.add(:base, 'Invalid buildpack-lifecycle-buildpack')
      end
    end
  end
end
