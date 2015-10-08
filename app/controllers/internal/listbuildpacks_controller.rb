module VCAP::CloudController
  class ListBuildpacksController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details('NotAuthenticated')
      end
    end

    get '/internal/buildpacks', :list
    def list
      dependency_locator = CloudController::DependencyLocator.instance
      buildpacks_presenter = AdminBuildpacksPresenter.new(dependency_locator.blobstore_url_generator)
      [HTTP::OK, MultiJson.dump(buildpacks_presenter.to_staging_message_array)]
    end
  end
end
