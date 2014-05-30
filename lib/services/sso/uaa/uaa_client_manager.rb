require 'uaa'

module VCAP::Services::SSO::UAA

  class UaaClientManager

    ROUTER_404_KEY   = 'X-Cf-Routererror'
    ROUTER_404_VALUE = 'unknown_route'

    def initialize(opts = {})
      @opts = opts
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

    def modify_transaction(changeset)
      return if changeset.empty?

      uri          = URI("#{uaa_target}/oauth/clients/tx/modify")
      use_ssl      = uri.instance_of?(URI::HTTPS)
      request_body = batch_request(changeset)

      request                  = Net::HTTP::Post.new(uri.path)
      request.body             = request_body.to_json
      request.content_type     = 'application/json'
      request['Authorization'] = token_info.auth_header

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = use_ssl
      if use_ssl
        http.verify_mode = verify_certs? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end

      logger.info("POST UAA transaction: #{uri.to_s} - #{scrub(request_body).to_json}")
      response = http.request(request)

      case response.code.to_i
        when 200..299
          return
        when 400
          log_bad_uaa_response(response)
          raise UaaResourceInvalid.new
        when 404
          log_bad_uaa_response(response)
          if response[ROUTER_404_KEY] == ROUTER_404_VALUE
            raise UaaUnavailable.new
          else
            raise UaaResourceNotFound.new
          end
        when 409
          log_bad_uaa_response(response)
          raise UaaResourceAlreadyExists.new
        else
          log_bad_uaa_response(response)
          raise UaaUnexpectedResponse.new
      end
    end

    private

    def verify_certs?
      !VCAP::CloudController::Config.config[:skip_cert_verify]
    end

    def log_bad_uaa_response(response)
      logger.error("UAA request failed with code: #{response.code} - #{response.inspect}")
    end

    def scrub(transaction_body)
      transaction_body.map do |client_request|
        client_request.delete(:client_secret)
        client_request
      end
    end

    def batch_request(changeset)
      changeset.map do |change|
        client_info = sso_client_info(change.client_attrs)
        client_info.merge(change.uaa_command)
      end
    end

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
    rescue CF::UAA::NotFound => e
      logger.error("UAA request for token failed: #{e.inspect}")
      raise UaaUnavailable.new
    end

    def sso_client_info(client_attrs)
      {
        client_id:              client_attrs['id'],
        client_secret:          client_attrs['secret'],
        redirect_uri:           client_attrs['redirect_uri'],
        scope:                  filter_uaa_client_scope,
        authorized_grant_types: ['authorization_code']
      }
    end

    def issuer_client_config
      uaa_client        = VCAP::CloudController::Config.config[:uaa_client_name]
      uaa_client_secret = VCAP::CloudController::Config.config[:uaa_client_secret]

      [uaa_client, uaa_client_secret] if uaa_client && uaa_client_secret
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_client_manager')
    end

    def filter_uaa_client_scope
      configured_scope = VCAP::CloudController::Config.config[:uaa_client_scope].split(',')
      filtered_scope = configured_scope.select do |val|
        ['cloud_controller.write', 'openid', 'cloud_controller.read', 'cloud_controller_service_permissions.read'].include?(val)
      end

      filtered_scope
    end
  end
end
