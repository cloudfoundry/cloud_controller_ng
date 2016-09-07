require 'uaa/info'

module VCAP
  class UaaTokenDecoder
    class BadToken < StandardError
    end

    attr_reader :config

    def initialize(config, grace_period_in_seconds=0)
      @config = config
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
      tries = 2
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
      options = { audience_ids: uaa_config[:resource_id] }.merge(options)
      token = CF::UAA::TokenCoder.new(options).decode_at_reference_time(auth_token, Time.now.utc.to_i - @grace_period_in_seconds)
      expiration_time = token['exp'] || token[:exp]
      if expiration_time && expiration_time < Time.now.utc.to_i
        @logger.warn("token currently expired but accepted within grace period of #{@grace_period_in_seconds} seconds")
      end
      token
    end

    def symmetric_key
      uaa_config[:symmetric_secret]
    end

    def uaa_config
      config[:uaa]
    end

    def asymmetric_key
      ssl_options = {
        skip_ssl_validation: config[:skip_cert_verify],
      }

      info = CF::UAA::Info.new(uaa_config[:url], ssl_options)
      @asymmetric_key ||= UaaVerificationKeys.new(info)
    end
  end
end
