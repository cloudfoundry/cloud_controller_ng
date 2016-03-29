require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/errors'
require 'cloud_controller/blobstore/webdav/dav_blob'
require 'cloud_controller/blobstore/webdav/nginx_secure_link_signer'

module CloudController
  module Blobstore
    class DavClient < BaseClient
      def initialize(options, directory_key, root_dir=nil, min_size=nil, max_size=nil)
        @options       = options
        @directory_key = directory_key
        @min_size      = min_size || 0
        @max_size      = max_size
        @root_dir      = root_dir

        @client = HTTPClient.new
        configure_ssl(@client, @options[:ca_cert_path])

        @endpoint = @options[:private_endpoint]
        @headers  = {}

        user     = @options[:username]
        password = @options[:password]
        if user && password
          @headers['Authorization'] = 'Basic ' +
            Base64.strict_encode64("#{user}:#{password}").strip
        end

        @signer = NginxSecureLinkSigner.new(
          internal_endpoint:    @options[:private_endpoint],
          internal_path_prefix: @directory_key,
          public_endpoint:      @options[:public_endpoint],
          public_path_prefix:   @directory_key,
          basic_auth_user:      user,
          basic_auth_password:  password
        )
      end

      def local?
        false
      end

      def exists?(key)
        response = with_error_handling do
          @client.head(url(key), header: @headers)
        end

        if response.status == 200
          true
        elsif response.status == 404
          false
        else
          raise BlobstoreError.new("Could not get object existence, #{response.status}/#{response.content}")
        end
      end

      def download_from_blobstore(source_key, destination_path, mode: nil)
        FileUtils.mkdir_p(File.dirname(destination_path))
        File.open(destination_path, 'wb') do |file|
          response = with_error_handling do
            @client.get(url(source_key), {}, @headers) do |block|
              file.write(block)
            end
          end

          raise BlobstoreError.new("Could not fetch object, #{response.status}/#{response.content}") if response.status != 200

          file.chmod(mode) if mode
        end
      end

      def cp_to_blobstore(source_path, destination_key, retries=2)
        start     = Time.now.utc
        log_entry = 'cp-skip'
        size      = -1

        logger.info('cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          with_retries(retries, 'cp', destination_key: destination_key) do
            response = with_error_handling { @client.put(url(destination_key), file, @headers) }

            raise BlobstoreError.new("Could not create object, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204
          end

          log_entry = 'cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry,
          destination_key:  destination_key,
          duration_seconds: duration,
          size:             size,
        )
      end

      def cp_file_between_keys(source_key, destination_key)
        destination_url    = url(destination_key)
        destination_header = { 'Destination' => destination_url }

        response = with_error_handling { @client.put(destination_url, '', @headers) }
        raise BlobstoreError.new("Could not copy object while creating destination, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204

        response = with_error_handling { @client.request(:copy, url(source_key), header: @headers.merge(destination_header)) }
        raise FileNotFound.new("Could not find object '#{source_key}', #{response.status}/#{response.content}") if response.status == 404
        raise BlobstoreError.new("Could not copy object, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204
      end

      def delete(key)
        response = with_error_handling { @client.delete(url(key), header: @headers) }
        return if response.status == 204

        raise FileNotFound.new("Could not find object '#{key}', #{response.status}/#{response.content}") if response.status == 404
        raise ConflictError.new("Conflict deleting object '#{key}', #{response.status}/#{response.content}") if response.status == 409
        raise BlobstoreError.new("Could not delete object, #{response.status}/#{response.content}")
      end

      def blob(key)
        response = with_error_handling { @client.head(url(key), header: @headers) }
        return DavBlob.new(httpmessage: response, key: partitioned_key(key), signer: @signer) if response.status == 200

        raise BlobstoreError.new("Could not get object, #{response.status}/#{response.content}") if response.status != 404
      end

      def delete_blob(blob)
        response = with_error_handling { @client.delete(url_from_blob_key(blob.key), header: @headers) }
        return if response.status == 404

        raise BlobstoreError.new("Could not delete object, #{response.status}/#{response.content}") if response.status != 204
      end

      def delete_all(_=nil)
        url      = url_without_key
        response = with_error_handling { @client.delete(url, header: @headers) }
        return if response.status == 204

        raise FileNotFound.new("Could not find object '#{URI(url).path}', #{response.status}/#{response.content}") if response.status == 404
        raise BlobstoreError.new("Could not delete all, #{response.status}/#{response.content}")
      end

      def delete_all_in_path(path)
        url      = url(path) + '/'
        response = with_error_handling { @client.delete(url, header: @headers) }
        return if response.status == 204

        raise FileNotFound.new("Could not find object '#{URI(url).path}', #{response.status}/#{response.content}") if response.status == 404
        raise BlobstoreError.new("Could not delete all in path, #{response.status}/#{response.content}")
      end

      def configure_ssl(httpclient, ca_cert_path)
        httpclient.ssl_config.verify_mode = skip_cert_verify ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        httpclient.ssl_config.set_default_paths

        if ca_cert_path && File.exist?(ca_cert_path)
          httpclient.ssl_config.add_trust_ca(ca_cert_path)
        end
      end

      private

      def skip_cert_verify
        VCAP::CloudController::Config.config[:skip_cert_verify]
      end

      def url(key)
        [@endpoint, 'admin', @directory_key, partitioned_key(key)].compact.join('/')
      end

      def url_from_blob_key(key)
        [@endpoint, 'admin', @directory_key, key].compact.join('/')
      end

      def url_without_key
        [@endpoint, 'admin', @directory_key, @root_dir].compact.join('/') + '/'
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.dav_client')
      end

      def with_retries(retries, log_prefix, log_data)
        yield
      rescue StandardError => e
        logger.debug("#{log_prefix}-retry",
          {
            error:             e,
            remaining_retries: retries
          }.merge(log_data)
        )

        retries -= 1
        retry unless retries < 0
        raise e
      end

      def with_error_handling
        yield
      rescue OpenSSL::SSL::SSLError => e
        logger.error("SSL verification failed: #{e.message}")
        raise BlobstoreError.new('SSL verification failed')
      end
    end
  end
end
