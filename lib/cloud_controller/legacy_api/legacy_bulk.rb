require 'sinatra'
require 'controllers/base/base_controller'

module VCAP::CloudController
  class BulkResponse < JsonMessage
    required :results do
      dict(
        any,
        {
          'id'              => String,
          'instances'       => Integer,
          'state'           => String,
          'package_state'   => String,
          'version'         => String
        },
      )
    end

    required :bulk_token, Hash
  end

  class UserCountsResponse < JsonMessage
    required :counts do
      {
        'user' => Integer,
      }
    end
  end

  class LegacyBulk < RestController::BaseController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    class << self
      attr_reader :config, :message_bus

      def configure(config, message_bus)
        @config = config[:bulk_api].merge(cc_partition: config.fetch(:cc_partition))
        @message_bus = message_bus
      end

      def register_subscription
        subject = "cloudcontroller.bulk.credentials.#{config[:cc_partition]}"
        message_bus.subscribe(subject) do |_, reply|
          message_bus.publish(
            reply,
            'user'      => config[:auth_user],
            'password'  => config[:auth_password],
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
        raise CloudController::Errors::NotAuthenticated
      end
    end

    def bulk_apps
      bulk_token = MultiJson.load(params.fetch('bulk_token'))
      last_id = Integer(bulk_token['id'] || 0)

      if last_id > 0
        return BulkResponse.new(
          results: {},
          bulk_token: { 'id' => 0 }
        ).encode
      end

      dependency_locator = ::CloudController::DependencyLocator.instance
      runners = dependency_locator.runners

      apps_hm9k, bulk_token_id = runners.dea_apps_hm9k
      app_hashes = apps_hm9k.each_with_object({}) { |app, acc| acc[app['id']] = app }

      BulkResponse.new(
        results: app_hashes,
        bulk_token: { 'id' => bulk_token_id }
      ).encode
    rescue IndexError => e
      raise ApiError.new_from_details('BadQueryParameter', e.message)
    end

    def bulk_user_count
      model = params.fetch('model', 'user')
      raise ApiError.new_from_details('BadQueryParameter', 'model') unless model == 'user'
      UserCountsResponse.new(
        counts: {
          'user' => User.count,
        },
      ).encode
    end

    get '/bulk/apps',     :bulk_apps
    get '/bulk/counts',   :bulk_user_count
  end
end
