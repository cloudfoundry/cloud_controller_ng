module VCAP::CloudController
  class BuildModel < Sequel::Model(:builds)
    STAGING_MEMORY = 1024 # This is weird, needed for app_usage_events. Resolved in later story (#141455831)
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

    add_association_dependencies buildpack_lifecycle_data: :delete

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
      save_changes(raise_on_save_failure: true)
    end

    def mark_as_staged
      self.state = STAGED_STATE
    end
  end
end
