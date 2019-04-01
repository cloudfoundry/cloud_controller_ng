require 'utils/uri_utils'

module VCAP::CloudController
  class BuildpackLifecycleBuildpackModel < Sequel::Model(:buildpack_lifecycle_buildpacks)
    set_field_as_encrypted :buildpack_url, salt: :encrypted_buildpack_url_salt, column: :encrypted_buildpack_url

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
        errors.add(:base, Sequel.lit('Must specify either a buildpack_url or an admin_buildpack_name'))
      elsif admin_buildpack_name.present?
        if Buildpack.find(name: admin_buildpack_name).nil?
          errors.add(:admin_buildpack_name, Sequel.lit("Specified unknown buildpack name: \"#{admin_buildpack_name}\""))
        end
      elsif !UriUtils.is_buildpack_uri?(buildpack_url)
        errors.add(:buildpack_url, Sequel.lit("Specified invalid buildpack URL: \"#{buildpack_url}\""))
      end
    end
  end
end
