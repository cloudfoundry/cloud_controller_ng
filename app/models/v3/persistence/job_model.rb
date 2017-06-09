module VCAP::CloudController
  class JobModel < Sequel::Model(:jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE   = 'COMPLETE'.freeze
    FAILED_STATE     = 'FAILED'.freeze

    RESOURCE_TYPE = { APP: 'app' }.freeze

    def complete?
      state != VCAP::CloudController::JobModel::COMPLETE_STATE
    end
  end
end
