require "sinatra"
require "controllers/base/base_controller"
require "cloud_controller/diego/diego_client"

module VCAP::CloudController
  class BulkAppsController < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    class << self
      attr_reader :config

      def configure(config)
        @config = config[:bulk_api]
      end

      def credentials
        [
          config[:auth_user],
          config[:auth_password],
        ]
      end
    end

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == self.class.credentials
        raise Errors::ApiError.new_from_details("NotAuthenticated")
      end
    end

    def bulk_apps
      batch_size = Integer(params.fetch("batch_size"))
      bulk_token = Yajl::Parser.parse(params.fetch("token"))
      last_id = Integer(bulk_token["id"] || 0)
      id_for_next_token = nil

      apps = []
      App.where(
        ["id > ?", last_id],
        "deleted_at IS NULL",
        ["state = ?", "STARTED"],
        ["package_state = ?", "STAGED"],
      ).order(:id).limit(batch_size).each do |app|
        apps << ::CloudController::DependencyLocator.instance.diego_client.desire_request(app)
        id_for_next_token = app.id
      end

      Yajl::Encoder.encode(
        apps: apps.collect(&:extract),
        token: { "id" => id_for_next_token }
      )
    rescue IndexError => e
      raise ApiError.new_from_details("BadQueryParameter", e.message)
    end

    get "/internal/bulk/apps",     :bulk_apps
  end
end
