module VCAP::CloudController
  class SyslogDrainUrlsController < RestController::ModelController
    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access
    class << self
      attr_reader :config

      def configure(config)
        @config = config[:bulk_api].merge(:cc_partition => config.fetch(:cc_partition))
      end

      def credentials
        [
          config[:auth_user],
          config[:auth_password],
        ]
      end
    end

    get '/v2/syslog_drain_urls', :list
    def list
      id_for_next_token = nil
      apps_with_bindings = App.
        select_all(:apps).
        join(:service_bindings, app_id: :id).
        where("apps.id > ?", last_id).
        where("syslog_drain_url IS NOT NULL").
        order(:app_id).
        distinct(:app_id).
        limit(batch_size)

      drain_urls = apps_with_bindings.inject({}) do |hash, app|
        drains = app.service_bindings.map(&:syslog_drain_url)
        hash[app.guid] = drains
        id_for_next_token = app.id
        hash
      end

      [HTTP::OK, {}, MultiJson.dump({results: drain_urls, next_id: id_for_next_token}, pretty: true)]
    end

    def last_id
      Integer(params.fetch("next_id",  0))
    end

    def batch_size
      Integer(params.fetch("batch_size", 50))
    end

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == self.class.credentials
        raise Errors::ApiError.new_from_details("NotAuthenticated")
      end
    end

  end
end
