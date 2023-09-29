require 'cloud_controller/diego/lifecycles/lifecycles'
require 'utils/uri_utils'

module VCAP::CloudController
  class BuildpackLifecycleDataModel < Sequel::Model(:buildpack_lifecycle_data)
    LIFECYCLE_TYPE = Lifecycles::BUILDPACK

    set_field_as_encrypted :buildpack_url, salt: :encrypted_buildpack_url_salt, column: :encrypted_buildpack_url

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

    many_to_one :app,
                class: '::VCAP::CloudController::AppModel',
                key: :app_guid,
                primary_key: :guid,
                without_guid_generation: true

    one_to_many :buildpack_lifecycle_buildpacks,
                class: '::VCAP::CloudController::BuildpackLifecycleBuildpackModel',
                key: :buildpack_lifecycle_data_guid,
                primary_key: :guid,
                order: :id
    plugin :nested_attributes
    nested_attributes :buildpack_lifecycle_buildpacks, destroy: true
    add_association_dependencies buildpack_lifecycle_buildpacks: :destroy

    alias_method :legacy_buildpack_url, :buildpack_url
    alias_method :legacy_buildpack_url=, :buildpack_url=
    alias_method :legacy_admin_buildpack_name, :admin_buildpack_name
    alias_method :legacy_admin_buildpack_name=, :admin_buildpack_name=

    def buildpacks
      if buildpack_lifecycle_buildpacks.present?
        buildpack_lifecycle_buildpacks.map(&:name)
      else
        legacy_buildpack_name = legacy_admin_buildpack_name || legacy_buildpack_url
        Array(legacy_buildpack_name)
      end
    end

    def buildpack_models
      if buildpack_lifecycle_buildpacks.present?
        buildpack_lifecycle_buildpacks.map do |buildpack|
          Buildpack.find(name: buildpack.name) || CustomBuildpack.new(buildpack.name)
        end
      else
        [legacy_buildpack_model]
      end
    end

    def buildpacks=(new_buildpacks)
      new_buildpacks ||= []
      first_buildpack = new_buildpacks.first
      # During the rolling-deploy transition period, update both old and new columns
      if UriUtils.is_buildpack_uri?(first_buildpack)
        self.legacy_buildpack_url = first_buildpack
      elsif first_buildpack.is_a?(String)
        self.legacy_admin_buildpack_name = first_buildpack
      elsif first_buildpack.nil?
        self.legacy_admin_buildpack_name = self.legacy_buildpack_url = nil
      end

      buildpacks_to_remove = buildpack_lifecycle_buildpacks.map { |bp| { id: bp.id, _delete: true } }
      buildpacks_to_add = new_buildpacks.map { |buildpack_url| attributes_from_buildpack(buildpack_url) }
      self.buildpack_lifecycle_buildpacks_attributes = buildpacks_to_add + buildpacks_to_remove
    end

    def using_custom_buildpack?
      buildpack_lifecycle_buildpacks.any?(&:custom?) || legacy_buildpack_model.custom?
    end

    def first_custom_buildpack_url
      buildpack_lifecycle_buildpacks.find(&:custom?)&.buildpack_url || legacy_buildpack_url
    end

    def to_hash
      {
        buildpacks: buildpacks.map { |buildpack| CloudController::UrlSecretObfuscator.obfuscate(buildpack) },
        stack: stack
      }
    end

    def validate
      return unless app && (build || droplet)

      errors.add(:lifecycle_data, 'Must be associated with an app OR a build+droplet, but not both')
    end

    private

    def attributes_from_buildpack_name(buildpack_name)
      if UriUtils.is_buildpack_uri?(buildpack_name)
        { buildpack_url: buildpack_name, admin_buildpack_name: nil }
      else
        { buildpack_url: nil, admin_buildpack_name: buildpack_name }
      end
    end

    def attributes_from_buildpack_key(key)
      admin_buildpack = Buildpack.find(key:)
      if admin_buildpack
        { buildpack_url: nil, admin_buildpack_name: admin_buildpack.name }
      elsif UriUtils.is_buildpack_uri?(key)
        { buildpack_url: key, admin_buildpack_name: nil }
      else
        {} # Will fail a validity check downstream
      end
    end

    def attributes_from_buildpack_hash(buildpack)
      {
        buildpack_name: buildpack[:name],
        version: buildpack[:version]
      }.merge(buildpack[:key] ? attributes_from_buildpack_key(buildpack[:key]) : attributes_from_buildpack_name(buildpack[:name]))
    end

    def attributes_from_buildpack(buildpack)
      if buildpack.is_a?(String)
        attributes_from_buildpack_name buildpack
      elsif buildpack.is_a?(Hash)
        attributes_from_buildpack_hash buildpack
      else
        # Don't set anything -- this will fail later on a validity check
        {}
      end
    end

    def legacy_buildpack
      return legacy_admin_buildpack_name if legacy_admin_buildpack_name.present?

      buildpack_url
    end

    def legacy_buildpack_model
      return AutoDetectionBuildpack.new if legacy_buildpack.nil?

      known_buildpack = Buildpack.find(name: legacy_buildpack)
      return known_buildpack if known_buildpack

      CustomBuildpack.new(legacy_buildpack)
    end
  end
end
