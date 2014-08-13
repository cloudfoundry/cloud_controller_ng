require "sinatra"
require "controllers/base/base_controller"

module VCAP::CloudController
  class BulkResponse < JsonMessage
    required :results do
      dict(
        any,
        {
          "id"              => String,
          "instances"       => Integer,
          "state"           => String,
          "memory"          => Integer,
          "package_state"   => String,
          "updated_at"      => Time,
          "version"         => String
        },
      )
    end
    required :bulk_token, Hash
  end

  class UserCountsResponse < JsonMessage
    required :counts do
      {
        "user" => Integer,
      }
    end
  end

  class LegacyBulk < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    class << self
      attr_reader :config, :message_bus

      def configure(config, message_bus)
        @config = config[:bulk_api].merge(:cc_partition => config.fetch(:cc_partition))
        @message_bus = message_bus
      end

      def register_subscription
        subject = "cloudcontroller.bulk.credentials.#{config[:cc_partition]}"
        message_bus.subscribe(subject) do |_, reply|
          message_bus.publish(
              reply,
              "user"      => config[:auth_user],
              "password"  => config[:auth_password],
          )
        end
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
      bulk_token = MultiJson.load(params.fetch("bulk_token"))
      last_id = Integer(bulk_token["id"] || 0)
      id_for_next_token = nil

      apps = {}
      App.where(
          ["id > ?", last_id],
          "deleted_at IS NULL"
      ).where(diego: false).order(:id).limit(batch_size).each do |app|
        hash = {}
        export_attributes = [
          :instances,
          :state,
          :memory,
          :package_state,
          :version
        ]
        export_attributes.each do |field|
          hash[field.to_s] = app.values.fetch(field)
        end
        hash["id"] = app.guid
        hash["updated_at"] = app.updated_at || app.created_at
        apps[app.guid] = hash
        id_for_next_token = app.id
      end
      BulkResponse.new(
        :results => apps,
        :bulk_token => { "id" => id_for_next_token }
      ).encode
    rescue IndexError => e
      raise ApiError.new_from_details("BadQueryParameter", e.message)
    end

    def bulk_user_count
      model = params.fetch("model", "user")
      raise ApiError.new_from_details("BadQueryParameter", "model") unless model == "user"
      UserCountsResponse.new(
        :counts => {
          "user" => User.count,
        },
      ).encode
    end

    get "/bulk/apps",     :bulk_apps
    get "/bulk/counts",   :bulk_user_count
  end
end
