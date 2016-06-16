module VCAP::CloudController
  class ListBuildpacksController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise CloudController::Errors::NotAuthenticated
      end
    end

    get '/internal/buildpacks', :list
    def list
      [HTTP::OK, MultiJson.dump(AdminBuildpacksPresenter.enabled_buildpacks)]
    end
  end
end
