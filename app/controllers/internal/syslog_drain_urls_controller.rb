module VCAP::CloudController
  class SyslogDrainUrlsInternalController < RestController::BaseController
    # Endpoint uses mutual tls for auth, handled by nginx
    allow_unauthenticated_access

    get '/internal/v4/syslog_drain_urls', :list

    def list
      prepare_aggregate_function
      guid_to_drain_maps = AppModel.
                           join(ServiceBinding.table_name, app_guid: :guid).
                           join(Space.table_name, guid: :apps__space_guid).
                           join(Organization.table_name, id: :spaces__organization_id).
                           where(Sequel.lit('syslog_drain_url IS NOT NULL')).
                           where(Sequel.lit("syslog_drain_url != ''")).
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

      next_page_token = nil
      drain_urls = {}

      guid_to_drain_maps.each do |guid_and_drains|
        drain_urls[guid_and_drains[:guid]] = {
          drains: guid_and_drains[:syslog_drain_urls].split(','),
          hostname: hostname_from_app_name(guid_and_drains[:organization_name], guid_and_drains[:space_name], guid_and_drains[:name])
        }
      end

      next_page_token = last_id + batch_size unless guid_to_drain_maps.empty?

      [HTTP::OK, MultiJson.dump({ results: drain_urls, next_id: next_page_token, v5_available: true }, pretty: true)]
    end

    get '/internal/v5/syslog_drain_urls', :listv5

    def listv5
      prepare_aggregate_function

      bindings = ServiceBinding.
                 join(:apps, guid: :app_guid).
                 join(:spaces, guid: :apps__space_guid).
                 join(:organizations, id: :spaces__organization_id).
                 select(
                   :service_bindings__syslog_drain_url,
                   :service_bindings__credentials,
                   :service_bindings__salt,
                   :service_bindings__encryption_key_label,
                   :service_bindings__encryption_iterations,
                   :service_bindings__app_guid,
                   :apps__name___app_name,
                   :spaces__name___space_name,
                   :organizations__name___organization_name
                 ).
                 where(service_bindings__syslog_drain_url: syslog_drain_urls_query).

                 each_with_object({}) { |item, injected|
                   syslog_drain_url = item[:syslog_drain_url]
                   credentials = item.credentials
                   cert = credentials&.fetch('cert', '') || ''
                   key = credentials&.fetch('key', '') || ''
                   ca = credentials&.fetch('ca', '') || ''
                   hostname = hostname_from_app_name(item[:organization_name], item[:space_name], item[:app_name])
                   app_guid = item[:app_guid]

                   injected_item = injected[syslog_drain_url] ||= {
                     url: syslog_drain_url,
                     binding_data_map: {}
                   }
                   cert_item = injected_item[:binding_data_map][[key, cert, ca]] ||= {
                     cert: cert,
                     key: key,
                     ca: ca,
                     apps: []
                   }
                   cert_item[:apps].push({ hostname: hostname, app_id: app_guid })

                   injected
                 }.values

      bindings.each do |binding|
        binding[:credentials] = binding[:binding_data_map].values
        binding.delete(:binding_data_map)
      end

      next_page_token = nil
      next_page_token = last_id + batch_size unless bindings.empty?
      [HTTP::OK, MultiJson.dump({ results: bindings, next_id: next_page_token }, pretty: true)]
    end

    private

    def syslog_drain_urls_query
      ServiceBinding.
        distinct.
        exclude(syslog_drain_url: nil).
        exclude(syslog_drain_url: '').
        select(:syslog_drain_url).
        order(:syslog_drain_url).
        limit(batch_size).
        offset(last_id)
    end

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

    def prepare_aggregate_function
      if AppModel.db.database_type == :mysql
        AppModel.db.run('SET SESSION group_concat_max_len = 1000000000')
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
