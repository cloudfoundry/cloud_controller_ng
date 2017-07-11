module VCAP::CloudController
  class PollableJobModel < Sequel::Model(:jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE   = 'COMPLETE'.freeze
    FAILED_STATE     = 'FAILED'.freeze

    RESOURCE_TYPE = { APP: 'app', PACKAGE: 'package', DROPLET: 'droplet' }.freeze

    def complete?
      state == VCAP::CloudController::PollableJobModel::COMPLETE_STATE
    end

    def self.delayed_job_pollable_guid(delayed_job)
      pollable_job = PollableJobModel.find(delayed_job_guid: delayed_job.guid)

      raise "No pollable job found for delayed_job '#{delayed_job.guid}'" if pollable_job.nil?

      pollable_job.guid
    end
  end
end
