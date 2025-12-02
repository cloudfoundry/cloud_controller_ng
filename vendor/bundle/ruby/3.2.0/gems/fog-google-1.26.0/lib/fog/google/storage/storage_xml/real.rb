# frozen_string_literal: true

module Fog
  module Google
    class StorageXML
      class Real
        include Utils

        # Initialize connection to Google Storage
        #
        # ==== Notes
        # options parameter must include values for :google_storage_access_key_id and
        # :google_storage_secret_access_key in order to create a connection
        #
        # ==== Examples
        #   google_storage = Storage.new(
        #     :google_storage_access_key_id => your_google_storage_access_key_id,
        #     :google_storage_secret_access_key => your_google_storage_secret_access_key
        #   )
        #
        # ==== Parameters
        # * options<~Hash> - config arguments for connection.  Defaults to {}.
        #
        # ==== Returns
        # * Storage object with connection to google.
        def initialize(options = {})
          @google_storage_access_key_id = options[:google_storage_access_key_id]
          @google_storage_secret_access_key = options[:google_storage_secret_access_key]
          @connection_options = options[:connection_options] || {}
          @hmac = Fog::HMAC.new("sha1", @google_storage_secret_access_key)
          @host = options[:host] || "storage.googleapis.com"
          @persistent = options.fetch(:persistent, true)
          @port       = options[:port] || 443
          @scheme     = options[:scheme] || "https"
          @path_style = options[:path_style] || false
        end

        def reload
          @connection.reset if @connection
        end

        def signature(params)
          string_to_sign = <<-DATA
#{params[:method]}
#{params[:headers]['Content-MD5']}
#{params[:headers]['Content-Type']}
#{params[:headers]['Date']}
DATA

          google_headers = {}
          canonical_google_headers = +""
          params[:headers].each do |key, value|
            google_headers[key] = value if key[0..6] == "x-goog-"
          end

          google_headers = google_headers.sort_by { |a| a[0] }
          google_headers.each do |key, value|
            canonical_google_headers << "#{key}:#{value}\n"
          end
          string_to_sign << canonical_google_headers.to_s

          canonical_resource = +"/"
          if subdomain = params.delete(:subdomain)
            canonical_resource << "#{CGI.escape(subdomain).downcase}/"
          end
          canonical_resource << params[:path].to_s
          canonical_resource << "?"
          (params[:query] || {}).keys.each do |key|
            if %w(acl cors location logging requestPayment versions versioning).include?(key)
              canonical_resource << "#{key}&"
            end
          end
          canonical_resource.chop!
          string_to_sign << canonical_resource.to_s

          signed_string = @hmac.sign(string_to_sign)
          Base64.encode64(signed_string).chomp!
        end

        def connection(scheme, host, port)
          uri = "#{scheme}://#{host}:#{port}"
          if @persistent
            unless uri == @connection_uri
              @connection_uri = uri
              reload
              @connection = nil
            end
          else
            @connection = nil
          end
          @connection ||= Fog::XML::Connection.new(uri, @persistent, @connection_options)
        end

        private

        def request(params, &block)
          params = request_params(params)
          scheme = params.delete(:scheme)
          host   = params.delete(:host)
          port   = params.delete(:port)

          params[:headers]["Date"] = Fog::Time.now.to_date_header
          params[:headers]["Authorization"] = "GOOG1 #{@google_storage_access_key_id}:#{signature(params)}"

          connection(scheme, host, port).request(params, &block)
        end
      end
    end
  end
end
