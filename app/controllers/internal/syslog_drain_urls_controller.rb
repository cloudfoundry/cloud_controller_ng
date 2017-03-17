module VCAP::CloudController
  class SyslogDrainUrlsInternalController < RestController::BaseController
    # Endpoint uses mutual tls for auth, handled by nginx
    allow_unauthenticated_access

    get '/internal/v4/syslog_drain_urls', :list
    def list
      guid_to_drain_maps = if Sequel::Model.db.database_type == :mssql
                             Sequel::Model.db.fetch("SET ANSI_NULLS, QUOTED_IDENTIFIER, CONCAT_NULL_YIELDS_NULL, ANSI_WARNINGS, ANSI_PADDING ON; SELECT
                                                         [APPS].[GUID],
                                                         [APPS].[NAME],
                                                         STUFF((
                                                             SELECT ',' + sb.SYSLOG_DRAIN_URL
                                                             FROM [SERVICE_BINDINGS] sb
                                                             WHERE [APPS].[GUID] = sb.[APP_GUID]
                                                             FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS [SYSLOG_DRAIN_URLS],
                                                         [SPACES].[NAME] AS [SPACE_NAME],
                                                         [ORGANIZATIONS].[NAME] AS [ORGANIZATION_NAME]
                                                     FROM [APPS]
                                                     INNER JOIN [SERVICE_BINDINGS] AS [T1] ON ([T1].[APP_GUID] = [APPS].[GUID])
                                                     INNER JOIN [SPACES] ON ([SPACES].[GUID] = [APPS].[SPACE_GUID])
                                                     INNER JOIN [ORGANIZATIONS] ON ([ORGANIZATIONS].[ID] = [SPACES].[ORGANIZATION_ID])
                                                     WHERE (([SYSLOG_DRAIN_URL] IS NOT NULL) AND ([SYSLOG_DRAIN_URL] != ''))
                                                     GROUP BY [APPS].[GUID], [APPS].[NAME], [SPACES].[NAME], [ORGANIZATIONS].[NAME]
                                                     ORDER BY [GUID] OFFSET #{last_id} ROWS FETCH NEXT #{batch_size} ROWS ONLY")
                           else
                             AppModel.
                               join(ServiceBinding, app_guid: :guid).
                               join(Space, guid: :apps__space_guid).
                               join(Organization, id: :spaces__organization_id).
                               where('syslog_drain_url IS NOT NULL').
                               where("syslog_drain_url != ''").
                               group(
                                 "#{AppModel.table_name}__guid".to_sym,
                               "#{AppModel.table_name}__name".to_sym,
                               "#{Space.table_name}__name".to_sym,
                               "#{Organization.table_name}__name".to_sym
                             ).
                               select(
                                 "#{AppModel.table_name}__guid".to_sym,
                               "#{AppModel.table_name}__name".to_sym,
                               aggregate_function("#{ServiceBinding.table_name}__syslog_drain_url".to_sym).as(:syslog_drain_urls)
                             ).
                               select_append("#{Space.table_name}__name___space_name".to_sym).
                               select_append("#{Organization.table_name}__name___organization_name".to_sym).
                               order(:guid).
                               limit(batch_size).
                               offset(last_id).
                               all
                           end
      next_page_token = nil
      drain_urls      = {}

      guid_to_drain_maps.each do |guid_and_drains|
        drain_urls[guid_and_drains[:guid]] = {
          drains:   guid_and_drains[:syslog_drain_urls].split(','),
          hostname: hostname_from_app_name(guid_and_drains[:organization_name], guid_and_drains[:space_name], guid_and_drains[:name])
        }
      end

      next_page_token = last_id + batch_size unless guid_to_drain_maps.empty?

      [HTTP::OK, {}, MultiJson.dump({ results: drain_urls, next_id: next_page_token }, pretty: true)]
    end

    private

    def hostname_from_app_name(*names)
      names.map { |name|
        name.gsub(/\s+/, '-').gsub(/[^-a-zA-Z0-9]+/, '').sub(/-+$/, '')[0..62]
      }.join('.')
    end

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
