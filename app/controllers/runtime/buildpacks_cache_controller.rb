require 'presenters/api/job_presenter'

module VCAP::CloudController
  class BuildpacksCacheController < RestController::BaseController
    path_base 'blobstores'

    delete "#{path}/buildpack_cache", :delete
    def delete
      raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') unless SecurityContext.roles.admin?

      job = Jobs::Enqueuer.new(queue: Jobs::Queues.generic).enqueue(Jobs::Runtime::BuildpackCacheCleanup.new)
      [HTTP::ACCEPTED, JobPresenter.new(job).to_json]
    end
  end
end
