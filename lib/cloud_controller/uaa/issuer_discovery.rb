require 'httpclient'

module VCAP::CloudController
  class IssuerDiscovery
    CACHE_TTL = 300

    def initialize(config)
      @config = config
      @lock = Mutex.new
    end

    def issuer
      @lock.synchronize do
        return @issuer if @expires_at && Time.now < @expires_at

        client = HTTPClient.new(base_url: @config[:internal_url])
        client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
        client.ssl_config.set_trust_ca(@config[:ca_file]) if @config[:ca_file].present?
        response = client.get('.well-known/openid-configuration')
        raise "Could not retrieve issuer information from UAA: #{response.status}" unless response.status == 200

        value = Oj.strict_load(response.body).fetch('issuer')
        raise 'UAA issuer discovery returned an empty issuer' unless value.is_a?(String) && value.present?

        @issuer = value
        @expires_at = Time.now + CACHE_TTL
        @issuer
      end
    end
  end
end
