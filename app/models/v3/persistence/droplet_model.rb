module VCAP::CloudController
  class DropletModel < Sequel::Model(:v3_droplets)
    include Serializer

    DROPLET_STATES = [
      PENDING_STATE = 'PENDING'.freeze,
      STAGING_STATE = 'STAGING'.freeze,
      FAILED_STATE  = 'FAILED'.freeze,
      STAGED_STATE  = 'STAGED'.freeze,
      EXPIRED_STATE = 'EXPIRED'.freeze,
    ].freeze
    COMPLETED_STATES = [
      FAILED_STATE,
      STAGED_STATE,
      EXPIRED_STATE
    ].freeze

    many_to_one :package, class: 'VCAP::CloudController::PackageModel', key: :package_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid
    one_to_one :buildpack_lifecycle_data,
      class:       'VCAP::CloudController::BuildpackLifecycleDataModel',
      key:         :droplet_guid,
      primary_key: :guid

    add_association_dependencies buildpack_lifecycle_data: :delete

    encrypt :environment_variables, salt: :salt, column: :encrypted_environment_variables
    serializes_via_json :environment_variables
    serializes_via_json :process_types

    def validate
      super
      validates_includes DROPLET_STATES, :state, allow_missing: true
    end

    def after_create
      super
      app_usage_event_repository.create_from_droplet(self, 'STAGING_STARTED')
    end

    def after_update
      super
      if entering_staged? || entering_failed?
        app_usage_event_repository.create_from_droplet(self, 'STAGING_STOPPED')
      end
    end

    def after_destroy
      super
      unless COMPLETED_STATES.include?(self.state)
        app_usage_event_repository.create_from_droplet(self, 'STAGING_STOPPED')
      end
    end

    def update_buildpack_receipt(detected_buildpack_key)
      detected_admin_buildpack = Buildpack.find(key: detected_buildpack_key)
      if detected_admin_buildpack
        update(
          buildpack_receipt_buildpack_guid: detected_admin_buildpack.guid,
          buildpack_receipt_buildpack: detected_admin_buildpack.name
        )
      end
    end

    def self.user_visible(user)
      dataset.
        join(AppModel.table_name, :"#{AppModel.table_name}__guid" => :"#{DropletModel.table_name}__app_guid").
        where(AppModel.user_visibility_filter(user)).
        select_all(DropletModel.table_name)
    end

    def blobstore_key
      File.join(guid, droplet_hash) if droplet_hash
    end

    def staged?
      self.state == STAGED_STATE
    end

    def mark_as_staged
      self.state = STAGED_STATE
    end

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if buildpack_lifecycle_data
      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if buildpack_lifecycle_data
      DockerLifecycleDataModel.new
    end

    private

    def entering_staged?
      column_changed?(:state) && self.state == STAGED_STATE
    end

    def entering_failed?
      column_changed?(:state) && self.state == FAILED_STATE
    end

    def app_usage_event_repository
      @repository ||= Repositories::Runtime::AppUsageEventRepository.new
    end
  end
end
