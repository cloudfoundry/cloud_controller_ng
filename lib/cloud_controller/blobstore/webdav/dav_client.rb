require 'cloud_controller/blobstore/base_client'
require 'cloud_controller/blobstore/errors'
require 'cloud_controller/blobstore/webdav/dav_blob'
require 'cloud_controller/blobstore/webdav/nginx_secure_link_signer'
require 'cloud_controller/blobstore/webdav/http_client_provider'
require 'nokogiri'

module CloudController
  module Blobstore
    class DavClient < BaseClient
      attr_reader :root_dir

      def initialize(
        directory_key:,
        httpclient:,
        signer:,
        endpoint:,
        user: nil,
        password: nil,
        root_dir: nil,
        min_size: nil,
        max_size: nil
      )
        @directory_key = directory_key
        @min_size      = min_size || 0
        @max_size      = max_size
        @root_dir      = root_dir
        @client        = httpclient
        @endpoint      = endpoint
        @headers       = {}

        if user && password
          @headers['Authorization'] = 'Basic ' +
                                      Base64.strict_encode64("#{user}:#{password}").strip
        end

        @signer = signer
      end

      def self.build(options, directory_key, root_dir=nil, min_size=nil, max_size=nil)
        new(
          directory_key: directory_key,
          httpclient: HTTPClientProvider.provide(ca_cert_path: options[:ca_cert_path], connect_timeout: options[:blobstore_timeout], receive_timeout: 120),
          signer: NginxSecureLinkSigner.build(options:, directory_key:),
          endpoint: options[:private_endpoint],
          user: options[:username],
          password: options[:password],
          root_dir: root_dir,
          min_size: min_size,
          max_size: max_size
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
          raise_blobstore_error("Could not get object existence, #{response.status}/#{response.content}")
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

          raise_blobstore_error("Could not fetch object, #{response.status}/#{response.content}") if response.status != 200

          file.chmod(mode) if mode
        end
      end

      def cp_to_blobstore(source_path, destination_key)
        start     = Time.now.utc
        log_entry = 'cp-skip'
        size      = -1

        logger.info('cp-start', destination_key: destination_key, source_path: source_path, bucket: @directory_key)

        File.open(source_path) do |file|
          size = file.size
          next unless within_limits?(size)

          response = with_error_handling { @client.put(url(destination_key), file, @headers) }

          raise_blobstore_error("Could not create object, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204

          log_entry = 'cp-finish'
        end

        duration = Time.now.utc - start
        logger.info(log_entry,
                    destination_key: destination_key,
                    duration_seconds: duration,
                    size: size)
      end

      def cp_file_between_keys(source_key, destination_key)
        destination_url    = url(destination_key)
        destination_header = { 'Destination' => destination_url }

        response = with_error_handling { @client.put(destination_url, '', @headers) }
        raise_blobstore_error("Could not copy object while creating destination, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204

        response = with_error_handling { @client.request(:copy, url(source_key), header: @headers.merge(destination_header)) }
        raise FileNotFound.new("Could not find object '#{source_key}', #{response.status}/#{response.content}") if response.status == 404

        raise_blobstore_error("Could not copy object, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204
      end

      def delete(key)
        response = with_error_handling { @client.delete(url(key), header: @headers) }
        return if response.status == 204

        raise FileNotFound.new("Could not find object '#{key}', #{response.status}/#{response.content}") if response.status == 404
        raise ConflictError.new("Conflict deleting object '#{key}', #{response.status}/#{response.content}") if response.status == 409

        raise_blobstore_error("Could not delete object, #{response.status}/#{response.content}")
      end

      def blob(key)
        response = with_error_handling { @client.head(url(key), header: @headers) }
        return DavBlob.new(httpmessage: response, key: partitioned_key(key), signer: @signer) if response.status == 200

        raise_blobstore_error("Could not get object, #{response.status}/#{response.content}") if response.status != 404
      end

      def delete_blob(blob)
        response = with_error_handling { @client.delete(url_from_blob_key(blob.key), header: @headers) }
        return if response.status == 404

        raise_blobstore_error("Could not delete object, #{response.status}/#{response.content}") if response.status != 204
      end

      def delete_all(_=nil)
        url      = url_without_key
        response = with_error_handling { @client.delete(url, header: @headers) }
        return if response.status == 204

        raise FileNotFound.new("Could not find object '#{URI(url).path}', #{response.status}/#{response.content}") if response.status == 404

        raise_blobstore_error("Could not delete all, #{response.status}/#{response.content}")
      end

      def delete_all_in_path(path)
        url      = url(path) + '/'
        response = with_error_handling { @client.delete(url, header: @headers) }
        return if response.status == 204

        # requesting to delete something which is already gone is ok
        return if response.status == 404

        raise_blobstore_error("Could not delete all in path, #{response.status}/#{response.content}")
      end

      def files_for(prefix, ignored_directory_prefixes=[])
        queue = ['']
        Enumerator.new do |yielder|
          until queue.empty?
            path = queue.shift

            request_url = url_without_key + path
            response = with_error_handling { @client.request(:propfind, request_url, nil, nil, @headers) }
            xml = Nokogiri::XML.parse(response.body)

            props = xml.xpath('//D:prop')[1..]
            props.each do |prop|
              full_path = get_full_path(path, prop.xpath('D:displayname').first.text)
              next if prefix && !full_path.start_with?(prefix)
              next if ignored_directory_prefixes.any? && full_path.start_with?(*ignored_directory_prefixes)

              if prop.xpath('D:resourcetype').children.empty?
                blob = DavBlob.new(key: full_path, httpmessage: nil, signer: nil)
                yielder << blob
              else
                queue.insert(0, full_path)
              end
            end
          end
        end
      end

      def ensure_bucket_exists
        # This is not relevant for webdav but it must be defined to conform to the
        # CloudController::Blobstore::Client interface
      end

      private

      def raise_blobstore_error(error_message)
        logger.error("Error with blobstore: #{error_message}")
        raise BlobstoreError.new(error_message)
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

      def get_full_path(path, display_name)
        if path.present?
          [path, display_name].join('/')
        else
          display_name
        end
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.dav_client')
      end

      def with_error_handling
        yield
      rescue OpenSSL::SSL::SSLError => e
        logger.error("SSL verification failed: #{e.message}")
        raise BlobstoreError.new('SSL verification failed')
      rescue StandardError => e
        raise_blobstore_error(e.message)
      end
    end
  end
end
