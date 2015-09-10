require 'presenters/api/job_presenter'

module VCAP::CloudController
  class BuildpacksCacheController < RestController::BaseController
    path_base 'blobstores'

    delete "#{path}/buildpack_cache", :delete
    def delete
      raise VCAP::Errors::ApiError.new_from_details('NotAuthorized') unless SecurityContext.roles.admin?
      job = Jobs::Enqueuer.new(Jobs::Runtime::BuildpackCacheCleanup.new, queue: 'cc-generic').enqueue
      [HTTP::CREATED, JobPresenter.new(job).to_json]
    end
  end
end
