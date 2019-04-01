require 'uaa'

module VCAP::Services::SSO::UAA
  class UaaClientManager
    ROUTER_404_KEY   = 'X-Cf-Routererror'.freeze
    ROUTER_404_VALUE = 'unknown_route'.freeze

    def initialize(opts={})
      @opts       = opts
      @uaa_client = create_uaa_client
    end

    def get_clients(client_ids)
      @uaa_client.get_clients(client_ids)
    end

    def modify_transaction(changeset)
      return if changeset.empty?

      uri          = URI("#{uaa_target}/oauth/clients/tx/modify")
      request_body = batch_request(changeset)

      request                  = Net::HTTP::Post.new(uri.path)
      request.body             = request_body.to_json
      request.content_type     = 'application/json'
      request['Authorization'] = uaa_client.token_info.auth_header

      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.ca_file     = uaa_ca_file
      http.cert_store  = OpenSSL::X509::Store.new
      http.cert_store.set_default_paths

      logger.info("POST UAA transaction: #{uri} - #{scrub(request_body).to_json}")
      response = http.request(request)

      case response.code.to_i
      when 200..299
        return
      when 400
        log_bad_uaa_response(response)
        raise VCAP::CloudController::UaaResourceInvalid.new
      when 404
        log_bad_uaa_response(response)
        if response[ROUTER_404_KEY] == ROUTER_404_VALUE
          raise VCAP::CloudController::UaaUnavailable.new
        else
          raise VCAP::CloudController::UaaResourceNotFound.new
        end
      when 409
        log_bad_uaa_response(response)
        raise VCAP::CloudController::UaaResourceAlreadyExists.new
      else
        log_bad_uaa_response(response)
        raise VCAP::CloudController::UaaUnexpectedResponse.new
      end
    end

    private

    attr_reader :uaa_client

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

    def sso_client_info(client_attrs)
      {
        client_id:              client_attrs['id'],
        client_secret:          client_attrs['secret'],
        redirect_uri:           client_attrs['redirect_uri'],
        scope:                  filter_uaa_client_scope,
        authorities:            ['uaa.resource'],
        authorized_grant_types: ['authorization_code']
      }
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_client_manager')
    end

    def filter_uaa_client_scope
      configured_scope = VCAP::CloudController::Config.config.get(:uaa_client_scope).split(',')
      filtered_scope   = configured_scope.select do |val|
        ['cloud_controller.write', 'openid', 'cloud_controller.read', 'cloud_controller_service_permissions.read'].include?(val)
      end

      filtered_scope
    end

    def create_uaa_client
      VCAP::CloudController::UaaClient.new(
        uaa_target: uaa_target,
        client_id:  VCAP::CloudController::Config.config.get(:uaa_client_name),
        secret:     VCAP::CloudController::Config.config.get(:uaa_client_secret),
        ca_file:    uaa_ca_file
      )
    end

    def uaa_ca_file
      VCAP::CloudController::Config.config.get(:uaa, :ca_file)
    end

    def uaa_target
      VCAP::CloudController::Config.config.get(:uaa, :internal_url)
    end
  end
end
