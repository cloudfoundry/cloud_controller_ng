module VCAP::CloudController
  class DropletModel < Sequel::Model(:droplets)
    include Serializer

    DROPLET_STATES = [
      STAGING_STATE         = 'STAGING'.freeze,
      COPYING_STATE         = 'COPYING'.freeze,
      FAILED_STATE          = 'FAILED'.freeze,
      STAGED_STATE          = 'STAGED'.freeze,
      EXPIRED_STATE         = 'EXPIRED'.freeze,
      PROCESSING_UPLOAD_STATE = 'PROCESSING_UPLOAD'.freeze,
    ].freeze
    FINAL_STATES = [
      FAILED_STATE,
      STAGED_STATE,
      EXPIRED_STATE
    ].freeze
    STAGING_FAILED_REASONS = %w(StagerError StagingError StagingTimeExpired NoAppDetectedError BuildpackCompileFailed
                                BuildpackReleaseFailed InsufficientResources NoCompatibleCell).map(&:freeze).freeze

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

    def error
      e = [error_id, error_description].compact.join(' - ')
      e.blank? ? nil : e
    end

    def validate
      super
      validates_includes DROPLET_STATES, :state, allow_missing: true
    end

    def after_create
      super
      unless copying? || processing_upload?
        app_usage_event_repository.create_from_droplet(self, 'STAGING_STARTED')
      end
    end

    def after_update
      super
      if !exiting_processing_upload? && (entering_staged? || entering_failed?)
        app_usage_event_repository.create_from_droplet(self, 'STAGING_STOPPED')
      end
    end

    def after_destroy
      super
      unless in_final_state? || copying? || processing_upload?
        app_usage_event_repository.create_from_droplet(self, 'STAGING_STOPPED')
      end
    end

    def set_buildpack_receipt(buildpack_key:, detect_output:, requested_buildpack:, buildpack_url: nil)
      self.buildpack_receipt_detect_output = detect_output

      if buildpack_key.present? && (admin_buildpack = Buildpack.find(key: buildpack_key))
        self.buildpack_receipt_buildpack_guid = admin_buildpack.guid
        self.buildpack_receipt_buildpack      = admin_buildpack.name
      elsif buildpack_url.present?
        self.buildpack_receipt_buildpack = buildpack_url
      else
        self.buildpack_receipt_buildpack = requested_buildpack
      end

      self.buildpack_receipt_buildpack = CloudController::UrlSecretObfuscator.obfuscate(buildpack_receipt_buildpack)
    end

    def blobstore_key(hash=nil)
      hash ||= droplet_hash
      File.join(guid, hash) if hash
    end

    def buildpack?
      lifecycle_type == BuildpackLifecycleDataModel::LIFECYCLE_TYPE
    end

    def docker?
      lifecycle_type == DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def staging?
      self.state == STAGING_STATE
    end

    def failed?
      self.state == FAILED_STATE
    end

    def staged?
      self.state == STAGED_STATE
    end

    def copying?
      self.state == COPYING_STATE
    end

    def processing_upload?
      self.state == PROCESSING_UPLOAD_STATE
    end

    def mark_as_staged
      self.state = STAGED_STATE
    end

    def fail_to_stage!(reason='StagingError')
      reason = 'StagingError' unless STAGING_FAILED_REASONS.include?(reason)

      self.state             = FAILED_STATE
      self.error_id          = reason
      self.error_description = CloudController::Errors::ApiError.new_from_details(reason, 'staging failed').message
      save_changes(raise_on_save_failure: true)
    end

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if buildpack_lifecycle_data
      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if buildpack_lifecycle_data
      DockerLifecycleDataModel.new
    end

    def in_final_state?
      FINAL_STATES.include?(self.state)
    end

    private

    def entering_staged?
      column_changed?(:state) && self.state == STAGED_STATE
    end

    def entering_failed?
      column_changed?(:state) && self.state == FAILED_STATE
    end

    def exiting_processing_upload?
      column_changed?(:state) && initial_value(:state) == PROCESSING_UPLOAD_STATE
    end

    def app_usage_event_repository
      @repository ||= Repositories::AppUsageEventRepository.new
    end
  end
end
