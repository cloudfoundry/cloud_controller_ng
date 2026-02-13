module VCAP::CloudController
  class SyslogDrainUrlsInternalController < RestController::BaseController
    # Endpoint uses mutual tls for auth, handled by nginx
    allow_unauthenticated_access

    get '/internal/v5/syslog_drain_urls', :list

    def list
      prepare_aggregate_function

      bindings = ServiceBinding.
                 join(:apps, guid: :app_guid).
                 join(:spaces, guid: :apps__space_guid).
                 join(:organizations, id: :spaces__organization_id).
                 join(:service_instances, guid: :service_bindings__service_instance_guid).
                 select(
                   :service_bindings__syslog_drain_url,
                   :service_bindings__credentials,
                   :service_bindings__salt,
                   :service_bindings__encryption_key_label,
                   :service_bindings__encryption_iterations,
                   :service_bindings__app_guid,
                   :service_bindings__service_instance_guid,
                   :apps__name___app_name,
                   :spaces__name___space_name,
                   :organizations__name___organization_name,
                   :service_instances__is_gateway_service___is_managed_service
                 ).
                 where(service_bindings__syslog_drain_url: syslog_drain_urls_query).

                 each_with_object({}) do |item, injected|
                   syslog_drain_url = item[:syslog_drain_url]

                   hostname = hostname_from_app_name(item[:organization_name], item[:space_name], item[:app_name])
                   app_guid = item[:app_guid]

                   cert, key, ca = fetch_credentials_from_cache(item)

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
                 end.values

      bindings.each do |binding|
        binding[:credentials] = binding[:binding_data_map].values
        binding.delete(:binding_data_map)
      end

      next_page_token = nil
      next_page_token = last_id + batch_size unless bindings.empty?
      [HTTP::OK, Oj.dump({ results: bindings, next_id: next_page_token }, mode: :compat)]
    end

    private

    def upsi_service_instance_credential_cache
      @upsi_service_instance_credential_cache ||= {}
    end

    # Service Binding credentials are stored as encrypted values in CCDB.
    # Decrypting them is computationally expensive and has caused performance
    # issues since this endpoint may decrypt credentials from thousands of service bindings.
    #
    # Since all user-provided service instance bindings share the same credentials
    # as their service instance we can safely cache the for a given service instance guid.
    def fetch_credentials_from_cache(item)
      if item[:is_managed_service]
        credentials = item.credentials
        cert = credentials&.fetch('cert', '') || ''
        key = credentials&.fetch('key', '') || ''
        ca = credentials&.fetch('ca', '') || ''
      else # service is user-provided
        upsi_service_instance_credential_cache[item.service_instance_guid] ||= {}

        if upsi_service_instance_credential_cache[item.service_instance_guid].empty?
          credentials = item.credentials
          upsi_service_instance_credential_cache[item.service_instance_guid]['cert'] = credentials&.fetch('cert', '') || ''
          upsi_service_instance_credential_cache[item.service_instance_guid]['key'] = credentials&.fetch('key', '') || ''
          upsi_service_instance_credential_cache[item.service_instance_guid]['ca'] = credentials&.fetch('ca', '') || ''
        end

        cert = upsi_service_instance_credential_cache[item.service_instance_guid].fetch('cert', '')
        key = upsi_service_instance_credential_cache[item.service_instance_guid].fetch('key', '')
        ca = upsi_service_instance_credential_cache[item.service_instance_guid].fetch('ca', '')
      end

      [cert, key, ca]
    end

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
      names.map do |name|
        name.gsub(/\s+/, '-').gsub(/[^-a-zA-Z0-9]+/, '').sub(/-+$/, '')[0..62]
      end.join('.')
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
      return unless AppModel.db.database_type == :mysql

      AppModel.db.run('SET SESSION group_concat_max_len = 1000000000')
    end

    def last_id
      Integer(params.fetch('next_id', 0))
    end

    def batch_size
      Integer(params.fetch('batch_size', 50))
    end
  end
end
