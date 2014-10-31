require "sinatra"
require "controllers/base/base_controller"
require "cloud_controller/diego/client"
require "cloud_controller/internal_api"

module VCAP::CloudController
  class BulkAppsController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details("NotAuthenticated")
      end
    end

    def bulk_apps
      batch_size = Integer(params.fetch("batch_size"))
      bulk_token = MultiJson.load(params.fetch("token"))
      last_id = Integer(bulk_token["id"] || 0)

      dependency_locator = ::CloudController::DependencyLocator.instance
      runners = dependency_locator.runners

      apps = runners.diego_apps(batch_size, last_id)
      messages = apps.map { |app| runners.runner_for_app(app).desire_app_message }
      id_for_next_token = apps.empty? ? nil : apps.last.id

      MultiJson.dump(
        apps: messages,
        token: {"id" => id_for_next_token}
      )
    rescue IndexError => e
      raise ApiError.new_from_details("BadQueryParameter", e.message)
    end

    get "/internal/bulk/apps", :bulk_apps
  end
end
