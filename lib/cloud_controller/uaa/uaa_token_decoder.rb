require 'uaa/info'

module VCAP::CloudController
  class UaaTokenDecoder
    class BadToken < StandardError
    end

    attr_reader :config

    def initialize(uaa_config, grace_period_in_seconds=0)
      @config = uaa_config
      @logger = Steno.logger('cc.uaa_token_decoder')

      raise ArgumentError.new('grace period should be an integer') unless grace_period_in_seconds.is_a? Integer

      @grace_period_in_seconds = grace_period_in_seconds
      if grace_period_in_seconds < 0
        @grace_period_in_seconds = 0
        @logger.warn("negative grace period interval '#{grace_period_in_seconds}' is invalid, changed to 0")
      end
    end

    def decode_token(auth_token)
      return unless token_format_valid?(auth_token)

      if symmetric_key
        decode_token_with_symmetric_key(auth_token)
      else
        decode_token_with_asymmetric_key(auth_token)
      end
    rescue CF::UAA::TokenExpired => e
      @logger.warn('Token expired')
      raise BadToken.new(e.message)
    rescue CF::UAA::DecodeError, CF::UAA::AuthError => e
      @logger.warn("Invalid bearer token: #{e.inspect} #{e.backtrace}")
      raise BadToken.new(e.message)
    end

    private

    def token_format_valid?(auth_token)
      auth_token && auth_token.upcase.start_with?('BEARER')
    end

    def decode_token_with_symmetric_key(auth_token)
      decode_token_with_key(auth_token, skey: symmetric_key)
    end

    def decode_token_with_asymmetric_key(auth_token)
      tries      = 2
      last_error = nil
      while tries > 0
        tries -= 1
        asymmetric_key.value.each do |key|
          begin
            return decode_token_with_key(auth_token, pkey: key)
          rescue CF::UAA::InvalidSignature => e
            last_error = e
          end
        end
        asymmetric_key.refresh
      end
      raise last_error
    end

    def decode_token_with_key(auth_token, options)
      options         = { audience_ids: config[:resource_id] }.merge(options)
      token           = CF::UAA::TokenCoder.new(options).decode_at_reference_time(auth_token, Time.now.utc.to_i - @grace_period_in_seconds)
      expiration_time = token['exp'] || token[:exp]
      if expiration_time && expiration_time < Time.now.utc.to_i
        @logger.warn("token currently expired but accepted within grace period of #{@grace_period_in_seconds} seconds")
      end

      raise BadToken.new('Incorrect issuer') if token['iss'] != uaa_issuer

      token
    end

    def symmetric_key
      config[:symmetric_secret]
    end

    def asymmetric_key
      @asymmetric_key ||= UaaVerificationKeys.new(uaa_client.info)
    end

    def uaa_client
      ::CloudController::DependencyLocator.instance.uaa_client
    end

    def uaa_issuer
      @uaa_issuer ||= with_request_error_handling do
        response = http_client.get('.well-known/openid-configuration')
        raise "Could not retrieve issuer information from UAA: #{response.status}" unless response.status == 200
        JSON.parse(response.body).fetch('issuer')
      end
    end

    def http_client
      uaa_target                    = config[:internal_url]
      uaa_ca                        = config[:ca_file]
      client                        = HTTPClient.new(base_url: uaa_target)
      client.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_PEER
      client.ssl_config.set_trust_ca(uaa_ca)
      client
    end

    def with_request_error_handling(&blk)
      tries ||= 3
      yield
    rescue
      retry unless (tries -= 1).zero?
      raise
    end
  end
end
