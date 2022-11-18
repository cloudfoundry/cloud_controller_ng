module VCAP::CloudController
  class PollableJobModel < Sequel::Model(:jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE = 'COMPLETE'.freeze
    FAILED_STATE = 'FAILED'.freeze
    POLLING_STATE = 'POLLING'.freeze

    one_to_many :warnings, class: 'VCAP::CloudController::JobWarningModel', key: :job_id

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
      pollable_job = PollableJobModel.find(delayed_job_guid: delayed_job_guid)

      raise "No pollable job found for delayed_job '#{delayed_job_guid}'" if pollable_job.nil?

      pollable_job
    end
  end
end
