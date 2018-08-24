module Credhub
  class Client
    def initialize(credhub_url, uaa_client)
      @credhub_url = credhub_url
      @uaa_client = uaa_client
    end

    def get_credential_by_name(reference_name)
      response = with_request_error_handling do
        client.get("/api/v1/data?name=#{reference_name}&current=true", nil, { 'Authorization' => auth_header, 'Content-Type' => 'application/json' })
      end
      response_body = JSON.parse(response.body)
      response_body['data'][0]['value']
    end

    private

    attr_reader :credhub_url, :uaa_client

    def with_request_error_handling(&_block)
      response = yield

      case response.status
      when 200
        response
      when 401
        logger.error('Unable to authenticate with CredHub')
        raise UnauthenticatedError.from_response(response)
      when 403
        logger.error('Not authorized to retrieve the credential')
        raise ForbiddenError.from_response(response)
      when 404
        logger.error('Credential not found in CredHub')
        raise CredentialNotFoundError.from_response(response)
      else
        logger.error("CredHub returned status code #{response.status}")
        raise BadResponseError.new("Server error, status: #{response.status}")
      end
    rescue SocketError, HTTPClient::BadResponseError => e
      logger.error("Unable to open connection with CredHub: #{e.class} - #{e.message}")
      raise BadResponseError.new('Server error, CredHub unreachable')
    rescue OpenSSL::OpenSSLError => e
      logger.error("OpenSSLError occurred while communicating with CredHub: #{e.class} - #{e.message}")
      raise Error.new('SSL error communicating with CredHub')
    end

    def client
      @client ||= build_client
    end

    def build_client
      client = HTTPClient.new(base_url: credhub_url)
      client.ssl_config.set_trust_ca(VCAP::CloudController::Config.config.get(:credhub_api, :ca_cert_path))
      client
    end

    def auth_header
      @auth_header ||= uaa_client.token_info.auth_header
    end

    def logger
      @logger ||= Steno.logger('cc.credhub_client')
    end
  end

  class Error < StandardError
    def self.from_response(response)
      response_body = JSON.parse(response.body)
      error_message = response_body['error']
      if response_body['error_description']
        error_message += ": #{response_body['error_description']}"
      end
      new(error_message)
    end
  end

  class BadResponseError < Error; end
  class CredentialNotFoundError < Error; end
  class ForbiddenError < Error; end
  class UnauthenticatedError < Error; end
end
