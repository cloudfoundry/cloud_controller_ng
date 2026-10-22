module VCAP::CloudController
  class PollableJobModel < Sequel::Model(:jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE = 'COMPLETE'.freeze
    FAILED_STATE = 'FAILED'.freeze
    POLLING_STATE = 'POLLING'.freeze

    # Bits-upload operations run on the per-API-instance LOCAL worker queue
    # (cc-<name>-<index>), which has a small, fixed number of workers. These are
    # the only pollable jobs that compete for those local worker slots, so for
    # fairness we count a user's active jobs among just these when deprioritizing.
    UPLOAD_OPERATIONS = %w[package.upload droplet.upload buildpack.upload].freeze
    ACTIVE_STATES = %w[PROCESSING POLLING].freeze

    one_to_many :warnings, class: 'VCAP::CloudController::JobWarningModel', key: :job_id
    one_to_many :sub_jobs, class: 'VCAP::CloudController::PollableJobModel', key: :root_job_guid, primary_key: :guid

    plugin :serialization
    add_association_dependencies warnings: :destroy

    def complete?
      state == VCAP::CloudController::PollableJobModel::COMPLETE_STATE
    end

    def resource_exists?
      return false if resource_type.empty?

      model = case resource_type
              when 'role'
                Role
              when 'organization_quota'
                QuotaDefinition
              when 'space_quota'
                SpaceQuotaDefinition
              when 'service_route_binding'
                RouteBinding
              when 'service_credential_binding'
                ServiceCredentialBinding::View
              else
                Sequel::Model(ActiveSupport::Inflector.pluralize(resource_type).to_sym)
              end

      !!model.where(guid: resource_guid).first
    end

    def self.find_by_delayed_job(delayed_job)
      find_by_delayed_job_guid(delayed_job.guid)
    end

    def self.find_by_delayed_job_guid(delayed_job_guid)
      pollable_job = PollableJobModel.find(delayed_job_guid:)

      raise "No pollable job found for delayed_job '#{delayed_job_guid}'" if pollable_job.nil?

      pollable_job
    end

    def self.find_active_delete(resource_guid:, operation:)
      PollableJobModel.first(resource_guid: resource_guid, operation: operation, state: [PROCESSING_STATE, POLLING_STATE])
    end

    def self.number_of_active_jobs_by_user(user_guid)
      PollableJobModel.where(state: ACTIVE_STATES, user_guid: user_guid).count
    end

    def self.number_of_active_upload_jobs_by_user(user_guid)
      PollableJobModel.where(state: ACTIVE_STATES, user_guid: user_guid, operation: UPLOAD_OPERATIONS).count
    end
  end
end
