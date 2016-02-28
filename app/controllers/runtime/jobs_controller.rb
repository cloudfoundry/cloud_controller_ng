require 'presenters/api/job_presenter'

module VCAP::CloudController
  class JobsController < RestController::ModelController
    path_base 'jobs'

    get path_guid, :read
    def read(guid)
      raise VCAP::Errors::ApiError.new_from_details('InsufficientScope') unless authenticated?
      job = Delayed::Job[guid: guid]
      JobPresenter.new(job).to_json
    end

    private

    def authenticated?
      SecurityContext.admin? || SecurityContext.scopes.include?('cloud_controller.read')
    end
  end
end
