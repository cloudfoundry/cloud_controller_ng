require 'repositories/app_usage_event_repository'

module VCAP::CloudController
  class BuildModel < Sequel::Model(:builds)
    STAGING_MEMORY = 1024
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
      STAGED_STATE = 'STAGED'.freeze,
      FAILED_STATE = 'FAILED'.freeze,
    ].freeze
    FINAL_STATES = [
      FAILED_STATE,
      STAGED_STATE,
    ].freeze
    STAGING_FAILED_REASONS = %w(StagerError StagingError StagingTimeExpired NoAppDetectedError BuildpackCompileFailed
                                BuildpackReleaseFailed InsufficientResources NoCompatibleCell).map(&:freeze).freeze

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
      class:       'VCAP::CloudController::BuildpackLifecycleDataModel',
      key:         :build_guid,
      primary_key: :guid

    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    add_association_dependencies buildpack_lifecycle_data: :destroy

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if buildpack_lifecycle_data
      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if buildpack_lifecycle_data
      DockerLifecycleDataModel.new
    end

    def staged?
      self.state == STAGED_STATE
    end

    def failed?
      self.state == FAILED_STATE
    end

    def staging?
      self.state == STAGING_STATE
    end

    def in_final_state?
      FINAL_STATES.include?(self.state)
    end

    def fail_to_stage!(reason='StagingError', details='staging failed')
      reason = 'StagingError' unless STAGING_FAILED_REASONS.include?(reason)

      self.state             = FAILED_STATE
      self.error_id          = reason
      self.error_description = CloudController::Errors::ApiError.new_from_details(reason, details).message

      self.db.transaction do
        record_staging_stopped
        save_changes(raise_on_save_failure: true)
      end
    end

    def mark_as_staged
      self.db.transaction do
        record_staging_stopped
        self.state = STAGED_STATE
      end
    end

    def record_staging_stopped
      app_usage_event_repository.create_from_build(self, 'STAGING_STOPPED')
    end

    private

    def app_usage_event_repository
      Repositories::AppUsageEventRepository.new
    end
  end
end
