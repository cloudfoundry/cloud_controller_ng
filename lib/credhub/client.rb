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
        raise UnauthenticatedError.from_response(response)
      when 403
        raise ForbiddenError.from_response(response)
      when 404
        raise CredentialNotFoundError.from_response(response)
      else
        raise BadResponseError.new("Server error, status: #{response.status}")
      end
    end

    def client
      @client ||= build_client
    end

    def build_client
      HTTPClient.new(base_url: credhub_url)
    end

    def auth_header
      @_uaa_auth_header ||= uaa_client.token_info.auth_header
    end
  end

  class Error < StandardError; end
  class BadResponseError < Error; end

  class CredentialNotFoundError < Error
    def self.from_response(response)
      response_body = JSON.parse(response.body)
      new(response_body['error'])
    end
  end

  class ForbiddenError < Error
    def self.from_response(response)
      response_body = JSON.parse(response.body)
      new(response_body['error'])
    end
  end

  class UnauthenticatedError < Error
    def self.from_response(response)
      response_body = JSON.parse(response.body)
      new("#{response_body['error']}: #{response_body['error_description']}")
    end
  end
end
