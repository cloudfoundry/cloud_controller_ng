module VCAP::CloudController
  class HistoricalJobModel < Sequel::Model(:jobs)
    PROCESSING_STATE = 'PROCESSING'.freeze
    COMPLETE_STATE = 'COMPLETE'.freeze
    FAILED_STATE = 'FAILED'.freeze

    RESOURCE_TYPE = { APP: 'app' }.freeze

    def complete?
      state != VCAP::CloudController::HistoricalJobModel::COMPLETE_STATE
    end
  end
end
