require 'net/http/post/multipart'
require 'cloud_controller/blobstore/bits_service/blob'

module CloudController
  module Blobstore
    class BitsServiceClient
      ResourceTypeNotPresent = Class.new(StandardError)

      def initialize(bits_service_options:, resource_type:)
        raise ResourceTypeNotPresent.new('Must specify resource type') unless resource_type

        @resource_type = resource_type
        @resource_type_singular = @resource_type.to_s.singularize
        @options = bits_service_options
      end

      def local?
        false
      end

      def exists?(key)
        response = head(private_http_client, resource_path(key))
        validate_response_code!([200, 302, 404], response)

        response.code.to_i != 404
      end

      def cp_to_blobstore(source_path, destination_key)
        filename = File.basename(source_path)
        with_file_attachment!(source_path, filename) do |file_attachment|
          body = { :"#{resource_type_singular}" => file_attachment }
          response = put(resource_path(destination_key), body)
          validate_response_code!(201, response)
        end
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))
        File.open(destination_path, 'wb') do |file|
          uri = URI(resolve_redirects(private_http_client, source_key))
          response = Net::HTTP.get_response(uri)
          validate_response_code!(200, response)
          file.write(response.body)
          file.chmod(mode) if mode
        end
      end

      def cp_file_between_keys(source_key, destination_key)
        temp_downloaded_file = Tempfile.new('foo')
        download_from_blobstore(source_key, temp_downloaded_file.path)
        cp_to_blobstore(temp_downloaded_file.path, destination_key)
      end

      def delete(key)
        response = delete_request(resource_path(key))
        validate_response_code!([204, 404], response)

        if response.code.to_i == 404
          raise FileNotFound.new("Could not find object '#{key}', #{response.code}/#{response.body}")
        end
      end

      def blob(key)
        BitsServiceBlob.new(
          guid: key,
          public_download_url: resolve_redirects(public_http_client, key),
          internal_download_url: resolve_redirects(private_http_client, key)
        )
      end

      def delete_blob(blob)
        delete(blob.guid)
      end

      def delete_all(_=nil)
        if :buildpack_cache != resource_type
          raise NotImplementedError
        else
          delete_request(resource_path('')).tap do |response|
            validate_response_code!(204, response)
          end
        end
      end

      def delete_all_in_path(path)
        if :buildpack_cache != resource_type
          raise NotImplementedError
        else
          delete_request(resource_path(path.to_s)).tap do |response|
            validate_response_code!(204, response)
          end
        end
      end

      private

      attr_reader :options, :resource_type, :resource_type_singular

      def resolve_redirects(http_client, path)
        path = resource_path(path)
        head(http_client, path).tap do |response|
          return response['location'] if response.code.to_i == 302
        end

        File.join(endpoint(http_client).to_s, path)
      end

      def validate_response_code!(expected_codes, response)
        return if Array(expected_codes).include?(response.code.to_i)

        error = {
          response_code: response.code,
          response_body: response.body,
          response: response
        }.to_json

        logger.error("UnexpectedResponseCode: expected '#{expected_codes}' got #{error}")

        fail BlobstoreError.new(error)
      end

      def resource_path(guid)
        prefix = resource_type == :buildpack_cache ? 'buildpack_cache/entries/' : resource_type
        File.join('/', prefix.to_s, guid.to_s)
      end

      def with_file_attachment!(file_path, filename, &block)
        validate_file! file_path

        File.open(file_path) do |file|
          attached_file = UploadIO.new(file, 'application/octet-stream', filename)
          yield attached_file
        end
      end

      def validate_file!(file_path)
        return if File.exist?(file_path)

        raise Errors::FileDoesNotExist.new("Could not find file: #{file_path}")
      end

      def head(http_client, path)
        request = Net::HTTP::Head.new(path)
        do_request(http_client, request)
      end

      def get(http_client, path)
        request = Net::HTTP::Get.new(path)
        do_request(http_client, request)
      end

      def post(path, body, header={})
        request = Net::HTTP::Post.new(path, header)

        request.body = body
        do_request(private_http_client, request)
      end

      def put(path, body, header={})
        request = Net::HTTP::Put::Multipart.new(path, body, header)
        do_request(private_http_client, request)
      end

      def delete_request(path)
        request = Net::HTTP::Delete.new(path)
        do_request(private_http_client, request)
      end

      def do_request(http_client, request)
        request_id = SecureRandom.uuid

        logger.info('Request', {
          method: request.method,
          path: request.path,
          address: http_client.address,
          port: http_client.port,
          vcap_id: VCAP::Request.current_id,
          request_id: request_id
        })

        request.add_field(VCAP::Request::HEADER_NAME, VCAP::Request.current_id)
        http_client.request(request).tap do |response|
          logger.info('Response', { code: response.code, vcap_id: VCAP::Request.current_id, request_id: request_id })
        end
      end

      def private_http_client
        @private_http_client ||= Net::HTTP.new(private_endpoint.host, private_endpoint.port)
      end

      def public_http_client
        @public_http_client ||= Net::HTTP.new(public_endpoint.host, public_endpoint.port)
      end

      def private_endpoint
        @private_endpoint ||= URI.parse(options[:private_endpoint])
      end

      def public_endpoint
        @public_endpoint ||= URI.parse(options[:public_endpoint])
      end

      def endpoint(http_client)
        http_client == public_http_client ? public_endpoint : private_endpoint
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore')
      end
    end
  end
end
