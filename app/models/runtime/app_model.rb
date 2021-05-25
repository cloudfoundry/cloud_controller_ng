require 'cloud_controller/database_uri_generator'
require 'cloud_controller/serializer'
require 'models/helpers/process_types'
require 'hashdiff'

module VCAP::CloudController
  class AppModel < Sequel::Model(:apps)
    include Serializer
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    many_to_many :routes, join_table: :route_mappings, left_key: :app_guid, left_primary_key: :guid, right_primary_key: :guid, right_key: :route_guid
    one_to_many :service_bindings, key: :app_guid, primary_key: :guid
    one_to_many :tasks, class: 'VCAP::CloudController::TaskModel', key: :app_guid, primary_key: :guid

    many_to_one :space, class: 'VCAP::CloudController::Space', key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :organization, join_table: Space.table_name, left_key: :guid, left_primary_key: :space_guid, right_primary_key: :id, right_key: :organization_id

    one_to_many :processes, class: 'VCAP::CloudController::ProcessModel', key: :app_guid, primary_key: :guid do |dataset|
      dataset.order(Sequel.asc(:created_at), Sequel.asc(:id))
    end

    one_to_many :packages, class: 'VCAP::CloudController::PackageModel', key: :app_guid, primary_key: :guid
    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :app_guid, primary_key: :guid
    one_to_many :builds, class: 'VCAP::CloudController::BuildModel', key: :app_guid, primary_key: :guid
    one_to_many :deployments, class: 'VCAP::CloudController::DeploymentModel', key: :app_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::AppLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::AppAnnotationModel', key: :resource_guid, primary_key: :guid
    one_to_many :revisions,
      class: 'VCAP::CloudController::RevisionModel',
      key: :app_guid,
      primary_key: :guid,
      order: [Sequel.asc(:created_at), Sequel.asc(:id)]

    one_to_many :sidecars, class: 'VCAP::CloudController::SidecarModel', key: :app_guid, primary_key: :guid

    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel', key: :droplet_guid, primary_key: :guid, without_guid_generation: true

    one_to_many :web_processes,
      class: 'VCAP::CloudController::ProcessModel',
      key: :app_guid,
      primary_key: :guid,
      conditions: { type: ProcessTypes::WEB } do |dataset|
        dataset.order(Sequel.asc(:created_at), Sequel.asc(:id))
      end

    one_to_one :buildpack_lifecycle_data,
                class: 'VCAP::CloudController::BuildpackLifecycleDataModel',
                key: :app_guid,
                primary_key: :guid

    one_to_one :kpack_lifecycle_data,
                class: 'VCAP::CloudController::KpackLifecycleDataModel',
                key: :app_guid,
                primary_key: :guid

    set_field_as_encrypted :environment_variables, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    add_association_dependencies buildpack_lifecycle_data: :destroy
    add_association_dependencies kpack_lifecycle_data: :destroy
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    strip_attributes :name

    plugin :after_initialize

    def after_initialize
      self.enable_ssh = Config.config.get(:default_app_ssh_access) if self.enable_ssh.nil?
    end

    def validate
      super
      validates_presence :name
      validates_format APP_NAME_REGEX, :name
      validate_environment_variables
      validate_droplet_is_staged

      validates_unique [:space_guid, :name], message: Sequel.lit("App with the name '#{name}' already exists.")
    end

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if self.buildpack_lifecycle_data
      return KpackLifecycleDataModel::LIFECYCLE_TYPE if self.kpack_lifecycle_data

      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if self.buildpack_lifecycle_data
      return kpack_lifecycle_data if self.kpack_lifecycle_data

      DockerLifecycleDataModel.new
    end

    def current_package
      droplet&.package
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

    def stopped?
      desired_state == ProcessModel::STOPPED
    end

    def deploying?
      deployments.any?(&:deploying?)
    end

    def self.user_visibility_filter(user)
      space_guids = Space.join(:spaces_developers, space_id: :id, user_id: user.id).select(:spaces__guid).
                    union(Space.join(:spaces_managers, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:spaces_application_supporters, space_id: :id, user_id: user.id).select(:spaces__guid)).
                    union(Space.join(:organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__guid))
      {
        apps__guid: AppModel.where(space: space_guids.all).select(:guid)
      }
    end

    def oldest_web_process
      web_processes.first
    end

    def newest_web_process
      web_processes.last
    end

    def latest_revision
      reload.revisions.last if revisions_enabled
    end

    def commands_by_process_type
      processes.
        select { |p| p.type != ProcessTypes::WEB || p == newest_web_process }.
        map    { |p| [p.type, p.command] }.to_h
    end

    private

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
