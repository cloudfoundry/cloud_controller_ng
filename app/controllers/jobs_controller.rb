require 'presenters/api/job_presenter'

module VCAP::CloudController
  rest_controller :Jobs do
    disable_default_routes
    path_base "jobs"

    def read(guid)
      job = Delayed::Job.find_by_guid(guid)
      JobPresenter.new(job).to_json
    end

    get "#{path_guid}", :read
  end
end