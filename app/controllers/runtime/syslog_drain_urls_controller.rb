module VCAP::CloudController
  class SyslogDrainUrlsController < RestController::BaseController
    # Endpoint does its own basic auth
    allow_unauthenticated_access

    authenticate_basic_auth('/v2/syslog_drain_urls') do
      [VCAP::CloudController::Config.config[:bulk_api][:auth_user],
       VCAP::CloudController::Config.config[:bulk_api][:auth_password]]
    end

    get '/v2/syslog_drain_urls', :list
    def list
      id_for_next_token = nil
      apps_with_bindings = App.
        select_all(:apps).
        join(:service_bindings, app_id: :id).
        where('apps.id > ?', last_id).
        where('syslog_drain_url IS NOT NULL').
        where("syslog_drain_url != ''").
        order(:app_id).
        distinct(:app_id).
        limit(batch_size).
        eager(:service_bindings).
        all

      drain_urls = apps_with_bindings.each_with_object({}) do |app, hash|
        drains = app.service_bindings.map(&:syslog_drain_url).reject(&:blank?)
        hash[app.guid] = drains
        id_for_next_token = app.id
      end

      [HTTP::OK, {}, MultiJson.dump({ results: drain_urls, next_id: id_for_next_token }, pretty: true)]
    end

    private

    def last_id
      Integer(params.fetch('next_id',  0))
    end

    def batch_size
      Integer(params.fetch('batch_size', 50))
    end
  end
end
