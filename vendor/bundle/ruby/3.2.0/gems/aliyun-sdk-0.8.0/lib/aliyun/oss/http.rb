# -*- encoding: utf-8 -*-

require 'rest-client'
require 'resolv'
require 'fiber'

module Aliyun
  module OSS

    ##
    # HTTP wraps the HTTP functionalities for accessing OSS RESTful
    # API. It handles the OSS-specific protocol elements, and
    # rest-client details for the user, which includes:
    # * automatically generate signature for every request
    # * parse response headers/body
    # * raise exceptions and capture the request id
    # * encapsulates streaming upload/download
    # @example simple get
    #   headers, body = http.get({:bucket => 'bucket'})
    # @example streaming download
    #   http.get({:bucket => 'bucket', :object => 'object'}) do |chunk|
    #     # handle chunk
    #   end
    # @example streaming upload
    #   def streaming_upload(&block)
    #     http.put({:bucket => 'bucket', :object => 'object'},
    #              {:body => HTTP::StreamPlayload.new(block)})
    #   end
    #
    #   streaming_upload do |stream|
    #     stream << "hello world"
    #   end
    class HTTP

      DEFAULT_CONTENT_TYPE = 'application/octet-stream'
      DEFAULT_ACCEPT_ENCODING = 'identity'
      STS_HEADER = 'x-oss-security-token'
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 120

      ##
      # A stream implementation
      # A stream is any class that responds to :read(bytes, outbuf)
      #
      class StreamWriter
        attr_reader :data_crc

        def initialize(crc_enable = false, init_crc = 0)
          @buffer = ""
          @producer = Fiber.new { yield self if block_given? }
          @producer.resume
          @data_crc = init_crc.to_i
          @crc_enable = crc_enable
        end

        def read(bytes = nil, outbuf = nil)
          ret = ""
          loop do
            if bytes
              fail if bytes < 0
              piece = @buffer.slice!(0, bytes)
              if piece
                ret << piece
                bytes -= piece.size
                break if bytes == 0
              end
            else
              ret << @buffer
              @buffer.clear
            end

            if @producer.alive?
              @producer.resume
            else
              break
            end
          end

          if outbuf
            # WARNING: Using outbuf = '' here DOES NOT work!
            outbuf.clear
            outbuf << ret
          end

          # Conform to IO#read(length[, outbuf]):
          # At end of file, it returns nil or "" depend on
          # length. ios.read() and ios.read(nil) returns
          # "". ios.read(positive-integer) returns nil.
          return nil if ret.empty? && !bytes.nil? && bytes > 0

          @data_crc = Aliyun::OSS::Util.crc(ret, @data_crc) if @crc_enable

          ret
        end

        def write(chunk)
          @buffer << chunk.to_s.force_encoding(Encoding::ASCII_8BIT)
          Fiber.yield
          self
        end

        alias << write

        def closed?
          false
        end

        def close
        end

        def inspect
          "@buffer: " + @buffer[0, 32].inspect + "...#{@buffer.size} bytes"
        end
      end

      include Common::Logging

      def initialize(config)
        @config = config
      end

      def get_request_url(bucket, object)
        url = @config.endpoint.dup
        url.query = nil
        url.fragment = nil 
        isIP = !!(url.host =~ Resolv::IPv4::Regex)
        url.host = "#{bucket}." + url.host if bucket && !@config.cname && !isIP
        url.path = '/'
        url.path << "#{bucket}/" if bucket && isIP
        url.path << CGI.escape(object) if object
        url.to_s
      end

      def get_resource_path(bucket, object)
        res = '/'
        res << "#{bucket}/" if bucket
        res << "#{object}" if object

        res
      end

      # Handle Net::HTTPRespoonse
      def handle_response(r, &block)
        # read all body on error
        if r.code.to_i >= 300
          r.read_body
        else
        # streaming read body on success
          encoding = r['content-encoding']
          if encoding == 'gzip'
            stream = StreamWriter.new { |s| r.read_body { |chunk| s << chunk } }
            reader = Zlib::GzipReader.new(stream)
            yield reader.read(16 * 1024) until reader.eof?
          elsif encoding == 'deflate'
            begin
              stream = Zlib::Inflate.new
              # 1.9.x doesn't support streaming inflate
              if RUBY_VERSION < '2.0.0'
                yield stream.inflate(r.read_body)
              else
                r.read_body { |chunk| stream << chunk }
                stream.finish { |chunk| yield chunk }
              end
            rescue Zlib::DataError
              # No luck with Zlib decompression. Let's try with raw deflate,
              # like some broken web servers do.
              stream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
              # 1.9.x doesn't support streaming inflate
              if RUBY_VERSION < '2.0.0'
                yield stream.inflate(r.read_body)
              else
                r.read_body { |chunk| stream << chunk }
                stream.finish { |chunk| yield chunk }
              end
            end
          else
            r.read_body { |chunk| yield chunk }
          end
        end
      end

      ##
      # helper methods
      #
      def get(resources = {}, http_options = {}, &block)
        do_request('GET', resources, http_options, &block)
      end

      def put(resources = {}, http_options = {}, &block)
        do_request('PUT', resources, http_options, &block)
      end

      def post(resources = {}, http_options = {}, &block)
        do_request('POST', resources, http_options, &block)
      end

      def delete(resources = {}, http_options = {}, &block)
        do_request('DELETE', resources, http_options, &block)
      end

      def head(resources = {}, http_options = {}, &block)
        do_request('HEAD', resources, http_options, &block)
      end

      def options(resources = {}, http_options = {}, &block)
        do_request('OPTIONS', resources, http_options, &block)
      end

      private
      # Do HTTP reqeust
      # @param verb [String] HTTP Verb: GET/PUT/POST/DELETE/HEAD/OPTIONS
      # @param resources [Hash] OSS related resources
      # @option resources [String] :bucket the bucket name
      # @option resources [String] :object the object name
      # @option resources [Hash] :sub_res sub-resources
      # @param http_options [Hash] HTTP options
      # @option http_options [Hash] :headers HTTP headers
      # @option http_options [Hash] :query HTTP queries
      # @option http_options [Object] :body HTTP body, may be String
      #  or Stream
      def do_request(verb, resources = {}, http_options = {}, &block)
        bucket = resources[:bucket]
        object = resources[:object]
        sub_res = resources[:sub_res]

        headers = http_options[:headers] || {}
        headers['user-agent'] = get_user_agent
        headers['date'] = Time.now.httpdate
        headers['content-type'] ||= DEFAULT_CONTENT_TYPE
        headers['accept-encoding'] ||= DEFAULT_ACCEPT_ENCODING
        headers[STS_HEADER] = @config.sts_token if @config.sts_token

        if body = http_options[:body]
          if body.respond_to?(:read)
            headers['transfer-encoding'] = 'chunked'
          else
            headers['content-md5'] = Util.get_content_md5(body)
          end
        end

        res = {
          :path => get_resource_path(bucket, object),
          :sub_res => sub_res,
        }

        if @config.access_key_id and @config.access_key_secret
          sig = Util.get_signature(@config.access_key_secret, verb, headers, res)
          headers['authorization'] = "OSS #{@config.access_key_id}:#{sig}"
        end

        logger.debug("Send HTTP request, verb: #{verb}, resources: " \
                      "#{resources}, http options: #{http_options}")

        # From rest-client:
        # "Due to unfortunate choices in the original API, the params
        # used to populate the query string are actually taken out of
        # the headers hash."
        headers[:params] = (sub_res || {}).merge(http_options[:query] || {})

        block_response = ->(r) { handle_response(r, &block) } if block
        request = RestClient::Request.new(
          :method => verb,
          :url => get_request_url(bucket, object),
          :headers => headers,
          :payload => http_options[:body],
          :block_response => block_response,
          :open_timeout => @config.open_timeout || OPEN_TIMEOUT,
          :read_timeout => @config.read_timeout || READ_TIMEOUT
        )
        response = request.execute do |resp, &blk|
          if resp.code >= 300
            e = ServerError.new(resp)
            logger.error(e.to_s)
            raise e
          else
            resp.return!(&blk)
          end
        end

        # If streaming read_body is used, we need to create the
        # RestClient::Response ourselves
        unless response.is_a?(RestClient::Response)
          if response.code.to_i >= 300
            body = response.body
            if RestClient::version < '2.1.0'
              body = RestClient::Request.decode(response['content-encoding'], response.body)
            end
            response = RestClient::Response.create(body, response, request)
            e = ServerError.new(response)
            logger.error(e.to_s)
            raise e
          end
          response = RestClient::Response.create(nil, response, request)
          response.return!
        end

        logger.debug("Received HTTP response, code: #{response.code}, headers: " \
                      "#{response.headers}, body: #{response.body}")

        response
      end

      def get_user_agent
        "aliyun-sdk-ruby/#{VERSION} ruby-#{RUBY_VERSION}/#{RUBY_PLATFORM}"
      end

    end # HTTP
  end # OSS
end # Aliyun

# Monkey patch rest-client to exclude the 'Content-Length' header when
# 'Transfer-Encoding' is set to 'chuncked'. This may be a problem for
# some http servers like tengine.
module RestClient
  module Payload
    class Base
      def headers
        ({'content-length' => size.to_s} if size) || {}
      end
    end
  end
end
