module VCAP::CloudController
  class ServiceAccountProvision
    class Conflict < StandardError; end

    def initialize(clients, identity_ca:)
      @clients = clients
      @identity_ca = identity_ca
    end

    def provision(account)
      failure = nil
      account.db.transaction(savepoint: true) do
        account.lock!
        raise Conflict.new('service account is disabled') unless account.enabled

        begin
          account.db.transaction(savepoint: true) do
            principal = User.first(guid: account.client_id)
            raise Conflict.new('principal identity collision') if principal && !principal.is_oauth_client

            desired = registration(account)
            existing = existing_client(account.client_id)
            if existing
              raise Conflict.new('client identity collision') unless matching_registration?(existing, desired)
            else
              @clients.add(:client, desired)
            end

            User.create(guid: account.client_id, is_oauth_client: true, active: true) unless principal
            account.update(status: 'ready')
          end
        rescue StandardError => e
          failure = e
          account.reload.update(status: 'failed')
        end
      end
      raise failure if failure

      account
    end

    private

    def matching_registration?(existing, desired)
      tls_keys = existing.keys.select { |key| key.start_with?('tls-client-auth-', 'tls_client_auth_') }
      return false unless tls_keys.sort == desired.keys.grep(/\Atls[-_]/).sort

      desired.all? do |key, value|
        actual = existing[key]
        actual = [] if key == 'scope' && !existing.key?(key)
        if value.is_a?(Array)
          actual.is_a?(Array) && actual.all? { |entry| entry.is_a?(String) } && actual.sort == value.sort
        else
          actual == value
        end
      end
    end

    def existing_client(client_id)
      @clients.get(:client, client_id)
    rescue CF::UAA::NotFound
      nil
    end

    def registration(account)
      {
        'client_id' => account.client_id,
        'authorized_grant_types' => ['client_credentials'],
        'authorities' => %w[cloud_controller.read cloud_controller.write],
        'scope' => [],
        'access_token_validity' => 300,
        'tls-client-auth-ca' => @identity_ca,
        'tls_client_auth_san_dns' => account.certificate_dns_san,
        'cf_service_account_guid' => account.guid
      }
    end
  end
end
