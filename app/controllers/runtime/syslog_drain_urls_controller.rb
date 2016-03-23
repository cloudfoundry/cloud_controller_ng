module VCAP::CloudController
  class SyslogDrainUrlsController < RestController::BaseController
    V2_APP = 'v2'.freeze
    V3_APP = 'v3'.freeze

    # Endpoint does its own basic auth
    allow_unauthenticated_access

    authenticate_basic_auth('/v2/syslog_drain_urls') do
      [VCAP::CloudController::Config.config[:bulk_api][:auth_user],
       VCAP::CloudController::Config.config[:bulk_api][:auth_password]]
    end

    get '/v2/syslog_drain_urls', :list
    def list
      next_page_token = nil

      guids_of_apps_with_drains =
        v2_apps_with_syslog_drains_dataset.
        union(v3_apps_with_syslog_drains_dataset, from_self: false, all: true).
        order(:guid).
        limit(batch_size).
        offset(last_id).
        to_hash_groups(:app_version, :guid)

      apps = v2_apps_from_guids(guids_of_apps_with_drains[V2_APP]) + v3_apps_from_guids(guids_of_apps_with_drains[V3_APP])

      drain_urls = {}
      apps.each do |app|
        drain_urls[app.guid] = app.service_bindings.map(&:syslog_drain_url)
        next_page_token = last_id + batch_size
      end

      [HTTP::OK, {}, MultiJson.dump({ results: drain_urls, next_id: next_page_token }, pretty: true)]
    end

    private

    def v2_apps_with_syslog_drains_dataset
      App.db[App.table_name].
        join(ServiceBinding.table_name, app_id: :id).
        where('syslog_drain_url IS NOT NULL').
        where("syslog_drain_url != ''").
        distinct("#{App.table_name}__guid".to_sym).
        select(
          "#{App.table_name}__guid".to_sym,
          Sequel.cast(V2_APP, String).as(:app_version)
        )
    end

    def v3_apps_with_syslog_drains_dataset
      AppModel.db[AppModel.table_name].
        join(ServiceBindingModel.table_name, app_id: :id).
        where('syslog_drain_url IS NOT NULL').
        where("syslog_drain_url != ''").
        distinct("#{AppModel.table_name}__guid".to_sym).
        select(
          "#{AppModel.table_name}__guid".to_sym,
          Sequel.cast(V3_APP, String).as(:app_version)
        )
    end

    def v2_apps_from_guids(guids)
      App.where(guid: guids).
        eager(service_bindings: proc { |ds| ds.where('syslog_drain_url IS NOT NULL').where("syslog_drain_url != ''") }).all
    end

    def v3_apps_from_guids(guids)
      AppModel.where(guid: guids).
        eager(service_bindings: proc { |ds| ds.where('syslog_drain_url IS NOT NULL').where("syslog_drain_url != ''") }).all
    end

    def last_id
      Integer(params.fetch('next_id', 0))
    end

    def batch_size
      Integer(params.fetch('batch_size', 50))
    end
  end
end
