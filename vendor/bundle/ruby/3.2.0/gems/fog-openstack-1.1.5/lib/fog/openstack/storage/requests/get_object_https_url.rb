module Fog
  module OpenStack
    class Storage
      class Real
        # Get an expiring object https url from Cloud Files
        #
        # ==== Parameters
        # * container<~String> - Name of container containing object
        # * object<~String> - Name of object to get expiring url for
        # * expires<~Time> - An expiry time for this url
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~String> - url for object
        def get_object_https_url(container, object, expires, options = {})
          create_temp_url(container, object, expires, "GET", {:port => 443}.merge(options).merge(:scheme => "https"))
        end

        # creates a temporary url
        #
        # ==== Parameters
        # * container<~String> - Name of container containing object
        # * object<~String> - Name of object to get expiring url for
        # * expires<~Time> - An expiry time for this url
        # * method<~String> - The method to use for accessing the object (GET, PUT, HEAD)
        # * options<~Hash> - An optional options hash
        #   * 'scheme'<~String> - The scheme to use (http, https)
        #   * 'host'<~String> - The host to use
        #   * 'port'<~Integer> - The port to use
        #   * 'filename'<~String> - Filename returned Content-Disposition response header
        #
        # ==== Returns
        # * response<~Excon::Response>:
        #   * body<~String> - url for object
        #
        # ==== See Also
        # http://docs.rackspace.com/files/api/v1/cf-devguide/content/Create_TempURL-d1a444.html
        # https://developer.openstack.org/api-ref/object-store/?expanded=get-object-content-and-metadata-detail#get-object-content-and-metadata
        def create_temp_url(container, object, expires, method, options = {})
          raise ArgumentError, "Insufficient parameters specified." unless container && object && expires && method
          raise ArgumentError, "Storage must be instantiated with the :openstack_temp_url_key option" if @openstack_temp_url_key.nil?

          scheme = options[:scheme] || @openstack_management_uri.scheme
          host = options[:host] || @openstack_management_uri.host
          port = options[:port] || @openstack_management_uri.port

          # POST not allowed
          allowed_methods = %w(GET PUT HEAD)
          unless allowed_methods.include?(method)
            raise ArgumentError, "Invalid method '#{method}' specified. Valid methods are: #{allowed_methods.join(', ')}"
          end

          expires = expires.to_i
          object_path_escaped   = "#{@path}/#{Fog::OpenStack.escape(container)}/#{Fog::OpenStack.escape(object, "/")}"
          object_path_unescaped = "#{@path}/#{Fog::OpenStack.escape(container)}/#{object}"
          string_to_sign = "#{method}\n#{expires}\n#{object_path_unescaped}"

          hmac = Fog::HMAC.new('sha1', @openstack_temp_url_key.to_s)

          query = {
            temp_url_sig: sig_to_hex(hmac.sign(string_to_sign)),
            temp_url_expires: expires
          }
          query[:filename] = options[:filename] if options[:filename]

          temp_url_options = {
            :scheme => scheme,
            :host   => host,
            :port   => port,
            :path   => object_path_escaped,
            :query  => query.map { |k, v| "#{k}=#{v}" }.join('&')
          }
          URI::Generic.build(temp_url_options).to_s
        end

        private

        def sig_to_hex(str)
          str.unpack("C*").map do |c|
            c.to_s(16)
          end.map do |h|
            h.size == 1 ? "0#{h}" : h
          end.join
        end
      end
    end
  end
end
