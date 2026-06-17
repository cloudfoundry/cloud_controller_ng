require 'repositories/app_usage_event_repository'

module VCAP::CloudController
  class BuildModel < Sequel::Model(:builds)
    STAGING_MEMORY = 1024
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
      STAGED_STATE = 'STAGED'.freeze,
      FAILED_STATE = 'FAILED'.freeze
    ].freeze
    FINAL_STATES = [
      FAILED_STATE,
      STAGED_STATE
    ].freeze
    STAGING_FAILED_REASONS = %w[StagerError StagingError StagingTimeExpired NoAppDetectedError BuildpackCompileFailed
                                BuildpackReleaseFailed InsufficientResources NoCompatibleCell
                                CNBGenericBuildFailed CNBDownloadBuildpackFailed CNBDetectFailed
                                CNBBuildFailed CNBExportFailed CNBLaunchFailed CNBRestoreFailed].map(&:freeze).freeze

    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                key: :app_guid,
                primary_key: :guid,
                without_guid_generation: true
    one_to_one :droplet,
               class: 'VCAP::CloudController::DropletModel',
               key: :build_guid,
               primary_key: :guid
    many_to_one :package,
                class: 'VCAP::CloudController::PackageModel',
                key: :package_guid,
                primary_key: :guid,
                without_guid_generation: true
    one_to_one :buildpack_lifecycle_data,
               class: 'VCAP::CloudController::BuildpackLifecycleDataModel',
               key: :build_guid,
               primary_key: :guid
    one_to_one :cnb_lifecycle_data,
               class: 'VCAP::CloudController::CNBLifecycleDataModel',
               key: :build_guid,
               primary_key: :guid

    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    one_to_many :labels, class: 'VCAP::CloudController::BuildLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::BuildAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies buildpack_lifecycle_data: :destroy, cnb_lifecycle_data: :destroy

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    def validate
      super
      validates_includes Lifecycles::TYPES, :lifecycle_type
    end

    def before_create
      # Inherit lifecycle_type from associated app if not explicitly set
      self[:lifecycle_type] = app&.lifecycle_type if self[:lifecycle_type].blank?

      super
    end

    def lifecycle_type
      return self[:lifecycle_type] if self[:lifecycle_type].present?

      # Fallback for records written before the lifecycle_type column
      # existed. Remove once existing rows are backfilled (see #5067).
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if buildpack_lifecycle_data
      return CNBLifecycleDataModel::LIFECYCLE_TYPE if cnb_lifecycle_data

      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def buildpack_lifecycle?
      lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
    end

    def cnb_lifecycle?
      lifecycle_type == CNBLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
      return cnb_lifecycle_data if lifecycle_type == CNBLifecycleDataModel::LIFECYCLE_TYPE

      DockerLifecycleDataModel.new
    end

    def staged?
      state == STAGED_STATE
    end

    def failed?
      state == FAILED_STATE
    end

    def staging?
      state == STAGING_STATE
    end

    def in_final_state?
      FINAL_STATES.include?(state)
    end

    def fail_to_stage!(reason='StagingError', details='staging failed')
      reason = 'StagingError' unless STAGING_FAILED_REASONS.include?(reason)

      self.state             = FAILED_STATE
      self.error_id          = reason
      self.error_description = CloudController::Errors::ApiError.new_from_details(reason, details).message

      db.transaction do
        record_staging_stopped
        save_changes(raise_on_save_failure: true)
      end
    end

    def mark_as_staged
      db.transaction do
        record_staging_stopped
        self.state = STAGED_STATE
      end
    end

    def record_staging_stopped
      return unless need_to_create_stop_event?

      app_usage_event_repository.create_from_build(self, 'STAGING_STOPPED')
    end

    private

    def need_to_create_stop_event?
      initial_value(:state) == STAGING_STATE
    end

    def app_usage_event_repository
      Repositories::AppUsageEventRepository.new
    end
  end
end
