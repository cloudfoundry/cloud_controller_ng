require 'uaa'

module VCAP::Services::UAA
  class UaaClientManager

    def initialize(opts = {})
      @opts = opts
    end

    def create(client_attrs)
      return unless issuer_client_config

      client_info = sso_client_info(client_attrs)

      scim.add(:client, client_info)
    end

    def update(client_attrs)
      client_id   = client_attrs['id']
      client_info = sso_client_info(client_attrs)

      scim.delete(:client, client_id)
      scim.add(:client, client_info)
    end

    def delete(client_id)
      scim.delete(:client, client_id)
    rescue CF::UAA::NotFound
    end

    def get_clients(client_ids)
      client_ids.map do |id|
        begin
          scim.get(:client, id)
        rescue CF::UAA::NotFound
          nil
        end
      end.compact
    end

    private

    def scim
      @opts.fetch(:scim) do
        CF::UAA::Scim.new(uaa_target, token_info.auth_header)
      end
    end

    def uaa_target
      VCAP::CloudController::Config.config[:uaa][:url]
    end

    def issuer
      uaa_client, uaa_client_secret = issuer_client_config
      CF::UAA::TokenIssuer.new(uaa_target, uaa_client, uaa_client_secret)
    end

    def token_info
      issuer.client_credentials_grant
    end

    def sso_client_info(client_attrs)
      {
        client_id:              client_attrs['id'],
        client_secret:          client_attrs['secret'],
        redirect_uri:           client_attrs['redirect_uri'],
        scope:                  ['openid', 'cloud_controller.read', 'cloud_controller.write'],
        authorized_grant_types: ['authorization_code']
      }
    end

    def issuer_client_config
      uaa_client        = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]

      [uaa_client, uaa_client_secret] if uaa_client && uaa_client_secret
    end

    def logger
      @logger ||= Steno.logger('cc.service_dashboard_client_creator')
    end
  end
end
