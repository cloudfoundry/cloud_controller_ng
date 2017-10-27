require 'cloud_controller/database_uri_generator'
require 'models/helpers/process_types'

module VCAP::CloudController
  class AppModel < Sequel::Model(:apps)
    include Serializer
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/

    many_to_many :routes, join_table: :route_mappings, left_key: :app_guid, left_primary_key: :guid, right_primary_key: :guid, right_key: :route_guid
    one_to_many :service_bindings, key: :app_guid, primary_key: :guid
    one_to_many :tasks, class: 'VCAP::CloudController::TaskModel', key: :app_guid, primary_key: :guid

    many_to_one :space, class: 'VCAP::CloudController::Space', key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :organization, join_table: Space.table_name, left_key: :guid, left_primary_key: :space_guid, right_primary_key: :id, right_key: :organization_id

    one_to_many :processes, class: 'VCAP::CloudController::ProcessModel', key: :app_guid, primary_key: :guid
    one_to_many :packages, class: 'VCAP::CloudController::PackageModel', key: :app_guid, primary_key: :guid
    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :app_guid, primary_key: :guid
    one_to_many :builds, class: 'VCAP::CloudController::BuildModel', key: :app_guid, primary_key: :guid

    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel', key: :droplet_guid, primary_key: :guid, without_guid_generation: true
    one_to_one :web_process, class: 'VCAP::CloudController::ProcessModel', key: :app_guid, primary_key: :guid, conditions: { type: ProcessTypes::WEB }

    one_to_one :buildpack_lifecycle_data,
                class: 'VCAP::CloudController::BuildpackLifecycleDataModel',
                key: :app_guid,
                primary_key: :guid

    encrypt :environment_variables, salt: :salt, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    add_association_dependencies buildpack_lifecycle_data: :destroy

    strip_attributes :name

    def before_save
      update_enable_ssh
      super
    end

    def validate
      validates_presence :name
      validates_format APP_NAME_REGEX, :name
      validate_environment_variables
      validate_droplet_is_staged

      validates_unique [:space_guid, :name], message: Sequel.lit('name must be unique in space')
    end

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if self.buildpack_lifecycle_data
      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if self.buildpack_lifecycle_data
      DockerLifecycleDataModel.new
    end

    def database_uri
      service_binding_uris = service_bindings.map do |binding|
        binding.credentials['uri'] if binding.credentials.present?
      end.compact
      DatabaseUriGenerator.new(service_binding_uris).database_uri
    end

    def staging_in_progress?
      builds.any?(&:staging?)
    end

    def docker?
      lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def buildpack?
      lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
    end

    private

    def update_enable_ssh
      self.enable_ssh = Config.config.get(:default_app_ssh_access) if self.enable_ssh.nil?

      if column_changed?(:enable_ssh)
        processes.each do |process|
          process.set_new_version
          process.save
        end
      end
    end

    def validate_environment_variables
      return unless environment_variables
      VCAP::CloudController::Validators::EnvironmentVariablesValidator.
        validate_each(self, :environment_variables, environment_variables)
    end

    def validate_droplet_is_staged
      if droplet && droplet.state != DropletModel::STAGED_STATE
        errors.add(:droplet, 'must be in staged state')
      end
    end
  end
end
