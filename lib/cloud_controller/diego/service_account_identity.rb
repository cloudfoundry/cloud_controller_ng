module VCAP::CloudController
  module Diego
    class ServiceAccountIdentity
      def initialize(app, config, account_guid: app.service_account_guid)
        @app = app
        @config = config
        @account_guid = account_guid
      end

      def certificate_properties
        account = ready_account
        attributes = { organizational_unit: ["organization:#{@app.organization_guid}", "space:#{@app.space_guid}", "app:#{@app.guid}"] }
        attributes[:service_account] = ::Diego::Bbs::Models::ServiceAccount.new(name: account.name) if account
        ::Diego::Bbs::Models::CertificateProperties.new(attributes)
      end

      def environment
        account = ready_account
        return {} unless account

        endpoint = @config.get(:service_account_token_endpoint)
        unless endpoint.is_a?(String) && endpoint.start_with?('https://')
          raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Service account token endpoint is not configured')
        end

        { 'VCAP_SERVICE_ACCOUNT' => {
          guid: account.guid, name: account.name, client_id: account.client_id,
          certificate_dns_san: account.certificate_dns_san, token_endpoint: endpoint
        } }
      end

      private

      def ready_account
        return unless @account_guid

        unless @config.get(:service_account_runtime_enabled) == true
          raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Service account runtime is not enabled')
        end

        account = ServiceAccountModel.first(guid: @account_guid)
        unless account && account.enabled && account.status == 'ready' && account.space_guid == @app.space_guid
          raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Service account is not ready for runtime credentials')
        end

        account
      end
    end
  end
end
