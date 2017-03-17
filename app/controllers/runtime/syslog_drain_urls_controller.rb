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
      # TODO: SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON to the table when it is created?
      guid_to_drain_maps = if Sequel::Model.db.database_type == :mssql
                             Sequel::Model.db.fetch("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON; SELECT [APPS].[GUID], STUFF((
                                SELECT ',' + sb.SYSLOG_DRAIN_URL
                                FROM [SERVICE_BINDINGS] sb
                                WHERE [APPS].[GUID] = sb.[APP_GUID]
                                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS [SYSLOG_DRAIN_URLS]
                                FROM [APPS] INNER JOIN (SELECT * FROM [SERVICE_BINDINGS]) AS [T1] ON ([T1].[APP_GUID] = [APPS].[GUID])
                                WHERE ((SYSLOG_DRAIN_URL IS NOT NULL) AND (SYSLOG_DRAIN_URL != ''))
                                GROUP BY [APPS].[GUID] ORDER BY [GUID] OFFSET #{last_id} ROWS FETCH NEXT #{batch_size} ROWS ONLY")
                           else
                            AppModel.join(ServiceBinding, app_guid: :guid).
                               where{ Sequel[:syslog_drain_url] !~ nil }.
                               where{ Sequel[:syslog_drain_url] !~ '' }.
                               group("#{AppModel.table_name}__guid".to_sym).
                               select(
                                 "#{AppModel.table_name}__guid".to_sym,
                                 aggregate_function("#{ServiceBinding.table_name}__syslog_drain_url".to_sym).as(:syslog_drain_urls)
                               ).
                               order(:guid).
                               limit(batch_size).
                               offset(last_id).
                               all
                           end
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
