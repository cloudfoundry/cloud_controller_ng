require 'jsonclient'

module RegistryBuddy
  class Client
    def initialize(host, port)
      @url = "http://#{host}:#{port}"
    end

    def post_package(package_guid, zip_file_path, registry)
      response = with_request_error_handling 200 do
        client.post('/packages',
          body: {
            'package_guid' => package_guid,
            'package_zip_path' => zip_file_path,
            'registry_base_path' => registry,
          }
        )
      end
      JSON.parse(response.body)
    end

    def delete_image(image_reference)
      with_request_error_handling 202 do
        client.delete('/images',
          body: JSON.dump(image_reference: image_reference)
        )
      end

      nil
    end

    private

    def client
      @client ||= JSONClient.new(base_url: @url)
    end

    def logger
      @logger ||= Steno.logger('cc.registry_buddy')
    end

    def with_request_error_handling(successful_status)
      response = yield

      case response.status
      when successful_status
        response
      when 400
        logger.error("RegistryBuddy returned: #{response.status} with #{response.body}")
        raise Error.new("Bad Request error, status: #{response.status}")
      when 422
        logger.error("RegistryBuddy returned: #{response.status} with #{response.body}")
        raise Error.new("Unprocessable Entity error, status: #{response.status}")
      else
        logger.error("RegistryBuddy returned: #{response.status} with #{response.body}")
        raise Error.new("Server error, status: #{response.status}")
      end
    end
  end

  class Error < StandardError; end
end
