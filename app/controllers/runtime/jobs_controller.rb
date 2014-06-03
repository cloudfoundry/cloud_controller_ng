require 'presenters/api/job_presenter'

module VCAP::CloudController
  class JobsController < RestController::ModelController
    allow_unauthenticated_access
    path_base "jobs"

    get "#{path_guid}", :read
    def read(guid)
      job = Delayed::Job[:guid => guid]
      JobPresenter.new(job).to_json
    end
  end
end
