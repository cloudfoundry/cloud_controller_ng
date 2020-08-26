module PackageImageUploader
  class Client
    def initialize(host, port)
      @url = "http://#{host}:#{port}"
    end

    def post_package(package_guid, zip_file_path, registry)
      response = with_request_error_handling do
        client.post('/packages',
        { package_zip_path: zip_file_path, package_guid: package_guid, registry_base_path: registry })
      end
      JSON.parse(response.body)
    end

    private

    def client
      HTTPClient.new(base_url: @url)
    end

    def logger
      @logger ||= Steno.logger('cc.package_image_uploader')
    end

    def with_request_error_handling(&_block)
      response = yield

      case response.status
      when 200
        response
      when 400
        logger.error("PackageImageUploader returned: #{response.status} with #{response.body}")
        raise Error.new("Bad Request error, status: #{response.status}")
      when 422
        logger.error("PackageImageUploader returned: #{response.status} with #{response.body}")
        raise Error.new("Unprocessable Entity error, status: #{response.status}")
      else
        logger.error("PackageImageUploader returned: #{response.status} with #{response.body}")
        raise Error.new("Server error, status: #{response.status}")
      end
    end
  end

  class Error < StandardError; end
end
