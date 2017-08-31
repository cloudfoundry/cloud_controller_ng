module VCAP::CloudController
  class SyslogDrainUrlsController < RestController::BaseController
    # Endpoint does its own basic auth
    allow_unauthenticated_access

    authenticate_basic_auth('/v2/syslog_drain_urls') do
      [VCAP::CloudController::Config.config.get(:bulk_api, :auth_user),
       VCAP::CloudController::Config.config.get(:bulk_api, :auth_password)]
    end

    get '/v2/syslog_drain_urls', :list
    def list
      guid_to_drain_maps = AppModel.
                           join(ServiceBinding.table_name, app_guid: :guid).
                           where(Sequel.lit('syslog_drain_url IS NOT NULL')).
                           where(Sequel.lit("syslog_drain_url != ''")).
                           group("#{AppModel.table_name}__guid".to_sym).
                           select(
                             "#{AppModel.table_name}__guid".to_sym,
          aggregate_function("#{ServiceBinding.table_name}__syslog_drain_url".to_sym).as(:syslog_drain_urls)
        ).
                           order(:guid).
                           limit(batch_size).
                           offset(last_id).
                           all

      next_page_token = nil
      drain_urls = {}

      guid_to_drain_maps.each do |guid_and_drains|
        drain_urls[guid_and_drains[:guid]] = guid_and_drains[:syslog_drain_urls].split(',')
      end

      next_page_token = last_id + batch_size unless guid_to_drain_maps.empty?

      [HTTP::OK, {}, MultiJson.dump({ results: drain_urls, next_id: next_page_token }, pretty: true)]
    end

    private

    def aggregate_function(column)
      if AppModel.db.database_type == :postgres
        Sequel.function(:string_agg, column, ',')
      elsif AppModel.db.database_type == :mysql
        Sequel.function(:group_concat, column)
      else
        raise 'Unknown database type'
      end
    end

    def last_id
      Integer(params.fetch('next_id', 0))
    end

    def batch_size
      Integer(params.fetch('batch_size', 50))
    end
  end
end
