require 'presenters/api/job_presenter'

module VCAP::CloudController
  rest_controller :Jobs do
    disable_default_routes
    path_base "jobs"

    def read(id)
      # TODO: make job have a guid in addition to the standard ID
      job = Delayed::Job.find_by_id(id)
      JobPresenter.new(job).to_json
    end

    get "#{path_guid}", :read
  end
end