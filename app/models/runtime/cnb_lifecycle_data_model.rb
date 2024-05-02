require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class CNBLifecycleDataModel < Sequel::Model(:cnb_lifecycle_data)
    LIFECYCLE_TYPE = Lifecycles::CNB

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
                key: :cnb_lifecycle_data_guid,
                primary_key: :guid,
                order: :id
    plugin :nested_attributes
    nested_attributes :buildpack_lifecycle_buildpacks, destroy: true
    add_association_dependencies buildpack_lifecycle_buildpacks: :destroy

    def buildpacks
      if buildpack_lifecycle_buildpacks.present?
        buildpack_lifecycle_buildpacks.map(&:name)
      else
        []
      end
    end

    def buildpack_models
      if buildpack_lifecycle_buildpacks.present?
        buildpack_lifecycle_buildpacks.map do |buildpack|
          CustomBuildpack.new(buildpack.name)
        end
      else
        []
      end
    end

    def buildpacks=(new_buildpacks)
      new_buildpacks ||= []

      buildpacks_to_remove = buildpack_lifecycle_buildpacks.map { |bp| { id: bp.id, _delete: true } }
      buildpacks_to_add = new_buildpacks.map { |buildpack_url| attributes_from_buildpack(buildpack_url) }
      self.buildpack_lifecycle_buildpacks_attributes = buildpacks_to_add + buildpacks_to_remove
    end

    def first_custom_buildpack_url
      buildpack_lifecycle_buildpacks.find(&:custom?)&.buildpack_url
    end

    def using_custom_buildpack?
      true
    end

    def attributes_from_buildpack(buildpack_name)
      { buildpack_url: buildpack_name, admin_buildpack_name: nil }
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
  end
end
