require 'cloud_controller/blobstore/errors'
require 'cloud_controller/blobstore/webdav/dav_blob'

module CloudController
  module Blobstore
    class DavClient
      def initialize(options, directory_key, min_size=nil, max_size=nil)
        @options       = options
        @directory_key = directory_key
        @min_size      = min_size || 0
        @max_size      = max_size

        @client = HTTPClient.new

        @endpoint = @options[:endpoint]
        @headers  = {}
        @secret = @options[:secret]

        user     = @options[:user]
        password = @options[:password]
        if user && password
          @headers['Authorization'] = 'Basic ' +
            Base64.strict_encode64("#{user}:#{password}").strip
        end
      end

      def local?
        false
      end

      def exists?(key)
        response = @client.head(url(key), header: @headers)
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
          response = @client.get(url(source_key), {}, @headers) do |block|
            file.write(block)
          end

          raise BlobstoreError.new("Could not fetch object, #{response.status}/#{response.content}") if response.status != 200

          file.chmod(mode) if mode
        end
      end

      def cp_r_to_blobstore(source_dir)
        Find.find(source_dir).each do |path|
          next unless File.file?(path)
          next unless within_limits?(File.size(path))

          sha1 = Digester.new.digest_path(path)
          next if exists?(sha1)

          cp_to_blobstore(path, sha1)
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
            response = @client.put(url(destination_key), file, @headers)

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
        destination_header = { 'Destination' => url(destination_key) }
        response           = @client.request(:copy, url(source_key), nil, nil, @headers.merge(destination_header))

        raise FileNotFound.new("Could not find object '#{source_key}', #{response.status}/#{response.content}") if (response.status == 404)
        raise BlobstoreError.new("Could not copy object, #{response.status}/#{response.content}") if response.status != 201 && response.status != 204
      end

      def delete(key)
        response = @client.delete(url(key), header: @headers)

        raise FileNotFound.new("Could not find object '#{key}', #{response.status}/#{response.content}") if (response.status == 404)
        raise BlobstoreError.new("Could not delete object, #{response.status}/#{response.content}") if response.status != 204
      end

      def blob(key)
        response = @client.head(url(key), header: @headers)

        return DavBlob.new(httpmessage: response, url: read_url(key), secret: @secret) if response.status == 200
        raise BlobstoreError.new("Could not get object, #{response.status}/#{response.content}") if response.status != 404
      end

      def delete_blob(blob)
        response = @client.delete(blob.url.to_s, header: @headers)

        return if response.status == 404
        raise BlobstoreError.new("Could not delete object, #{response.status}/#{response.content}") if response.status != 204
      end

      def download_uri(key)
        b = blob(key)
        b.download_url if b
      end

      def delete_all(_=nil)
        # TODO: THis seems dangerous and have not added error handling yet
        response = @client.delete(url(''), header: @headers)

        with_retries(5, 'delete-all', {}) do
          response = @client.request(:mkcol, url(''), nil, nil, @headers)
          raise 'error' unless response.status == 201
        end
      end

      def delete_all_in_path(path)
      end

      def files
      end

      private

      def url(key)
        key = partitioned_key(key) unless key.blank?
        [@endpoint, 'admin', @directory_key, key].compact.join('/')
      end

      def read_url(key)
        key = partitioned_key(key) unless key.blank?
        [@endpoint, 'read', @directory_key, key].compact.join('/')
      end

      def partitioned_key(key)
        key = key.to_s.downcase
        key = File.join(key[0..1], key[2..3], key)
        if @root_dir
          key = File.join(@root_dir, key)
        end
        key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore.dav_client')
      end

      def with_retries(retries, log_prefix, log_data, &blk)
        blk.call
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
    end
  end
end
