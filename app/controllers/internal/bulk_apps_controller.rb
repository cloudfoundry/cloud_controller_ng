require "sinatra"
require "controllers/base/base_controller"
require "cloud_controller/diego/client"
require "cloud_controller/diego/staged_apps_query"
require "cloud_controller/bulk_api"

module VCAP::CloudController
  class BulkAppsController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == BulkApi.credentials
        raise Errors::ApiError.new_from_details("NotAuthenticated")
      end
    end

    def bulk_apps
      batch_size = Integer(params.fetch("batch_size"))
      bulk_token = MultiJson.load(params.fetch("token"))
      last_id = Integer(bulk_token["id"] || 0)

      staged_apps_query = Diego::StagedAppsQuery.new(batch_size, last_id)
      staged_apps = staged_apps_query.all

      dependency_locator = ::CloudController::DependencyLocator.instance
      backends = dependency_locator.backends

      apps = []
      id_for_next_token = nil
      staged_apps.each do |app|
        msg = backends.find_one_to_run(app).desire_app_message
        apps << msg
        id_for_next_token = app.id
      end

      MultiJson.dump(
        apps: apps,
        token: {"id" => id_for_next_token}
      )
    rescue IndexError => e
      raise ApiError.new_from_details("BadQueryParameter", e.message)
    end

    get "/internal/bulk/apps", :bulk_apps
  end
end
