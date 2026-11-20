require 'uri'

module VCAP::CloudController
  module Diego
    class ServiceAccountIdentity
      class NotReady < CloudController::Errors::ApiError; end

      def initialize(app, config, account_guid: app.service_account_guid)
        @app = app
        @config = config
        @account_guid = account_guid
      end

      def certificate_properties
        account = ready_account
        attributes = { organizational_unit: ["organization:#{@app.organization_guid}", "space:#{@app.space_guid}", "app:#{@app.guid}"] }
        attributes[:service_account] = ::Diego::Bbs::Models::ServiceAccount.new(name: account.name, prefix: account.identity_prefix) if account
        ::Diego::Bbs::Models::CertificateProperties.new(attributes)
      end

      def environment
        account = ready_account
        return {} unless account

        endpoint = @config.get(:service_account_token_endpoint)
        raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Service account token endpoint is not configured') unless valid_endpoint?(endpoint)

        { 'VCAP_SERVICE_ACCOUNT' => {
          guid: account.guid, name: account.name, client_id: account.client_id,
          certificate_dns_san: account.certificate_dns_san, token_endpoint: endpoint
        } }
      end

      private

      def valid_endpoint?(endpoint)
        return false unless endpoint.is_a?(String)

        uri = URI.parse(endpoint)
        uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
      rescue URI::InvalidURIError
        false
      end

      def ready_account
        return unless @account_guid

        unless @config.get(:service_accounts_enabled) == true
          raise CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Service account runtime is not enabled')
        end

        account = ServiceAccountModel.first(guid: @account_guid)
        unless account && account.enabled && account.status == 'ready' && account.entitled_to?(@app.space)
          raise NotReady.new_from_details('UnprocessableEntity', 'Service account is not ready for runtime credentials')
        end

        account
      end
    end
  end
end
