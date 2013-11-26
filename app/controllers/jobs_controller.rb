require 'presenters/api/job_presenter'

module VCAP::CloudController
  rest_controller :Jobs do
    allow_unauthenticated_access
    disable_default_routes
    path_base "jobs"

    get "#{path_guid}", :read
    def read(guid)
      job = Delayed::Job[:guid => guid]
      JobPresenter.new(job).to_json
    end
  end
end
