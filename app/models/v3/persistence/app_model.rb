module VCAP::CloudController
  class AppModel < Sequel::Model(:apps_v3)
    include Serializer
    APP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    many_to_many :routes, join_table: :apps_v3_routes, left_key: :app_v3_id

    many_to_one :space, class: 'VCAP::CloudController::Space', key: :space_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :organization, join_table: Space.table_name, left_key: :guid, left_primary_key: :space_guid, right_primary_key: :guid, right_key: :space_guid

    one_to_many :processes, class: 'VCAP::CloudController::App', key: :app_guid, primary_key: :guid
    one_to_many :packages, class: 'VCAP::CloudController::PackageModel', key: :app_guid, primary_key: :guid
    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :app_guid, primary_key: :guid
    many_to_one :droplet, class: 'VCAP::CloudController::DropletModel', key: :droplet_guid, primary_key: :guid, without_guid_generation: true

    one_to_one :buildpack_lifecycle_data,
                class: 'VCAP::CloudController::BuildpackLifecycleDataModel',
                key: :app_guid,
                primary_key: :guid

    encrypt :environment_variables, salt: :salt, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    add_association_dependencies buildpack_lifecycle_data: :delete

    def validate
      validates_presence :name
      validates_unique [:space_guid, :name]
      validates_format APP_NAME_REGEX, :name
      validate_environment_variables
      validate_droplet_is_staged
    end

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if self.buildpack_lifecycle_data
    end

    def lifecycle_data
      return buildpack_lifecycle_data if self.buildpack_lifecycle_data
    end

    class << self
      def user_visible(user)
        dataset.where(user_visibility_filter(user))
      end

      def user_visibility_filter(user)
        {
          space_guid: space_guids_where_visible(user)
        }
      end

      private

      def space_guids_where_visible(user)
        Space.join(:spaces_developers, space_id: :id, user_id: user.id).select(:spaces__guid).
        union(
          Space.join(:spaces_managers, space_id: :id, user_id: user.id).select(:spaces__guid)
        ).union(
          Space.join(:spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__guid)
        ).union(
          Space.join(:organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__guid)
        ).select(:space_guid)
      end
    end

    private

    def validate_environment_variables
      return unless environment_variables
      validator = VCAP::CloudController::Validators::EnvironmentVariablesValidator.new({ attributes: [:environment_variables] })
      validator.validate_each(self, :environment_variables, environment_variables)
    end

    def validate_droplet_is_staged
      if droplet && droplet.state != DropletModel::STAGED_STATE
        errors.add(:droplet, 'must be in staged state')
      end
    end
  end
end
