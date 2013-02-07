require "uaa/misc"

module VCAP
  module UaaUtil
    MIN_KEY_AGE = 600
    MIN_KEY_ACQUIRE = 20

    REDIS_UAA_VERIFY_KEY = 'cc.verification_key'.freeze
    REDIS_UAA_VERIFY_QUERIED_AT = 'cc.verification_queried_at'.freeze
    REDIS_UAA_VERIFY_SET_AT = 'cc.verification_set_at'.freeze

    def decode_token(auth_token)
      return unless token_format_valid?(auth_token)

      if symmetric_key
        decode_token_with_symmetric_key(auth_token)
      else
        decode_token_with_asymmetric_key(auth_token)
      end
    end

    private

    def decode_token_with_symmetric_key(auth_token)
      decode_token_with_key(auth_token, :skey => symmetric_key)
    end

    def decode_token_with_asymmetric_key(auth_token)
      verification_key = get_cached_verification_key || uaa_config[:verification_key] || fetch_verification_key

      begin
        token_information = decode_token_with_key(auth_token, :pkey => verification_key)
        logger.info("Token received from the UAA #{token_information.inspect}")
        cache_verification_key(verification_key) if token_information
        token_information
      rescue CF::UAA::InvalidSignature => e
        old_verification_key = verification_key
        verification_key = fetch_verification_key
        if verification_key
          logger.warn "#{auth_token} failed with #{old_verification_key}; try #{verification_key}"
          retry
        end
        raise
      end
    end

    def decode_token_with_key(auth_token, options)
      options = { :audience_ids => uaa_config[:resource_id]}.merge(options)
      CF::UAA::TokenCoder.new(options).decode(auth_token)
    end

    def fetch_verification_key
      key_age = Time.now - get_cached_time(REDIS_UAA_VERIFY_SET_AT)
      if key_age < MIN_KEY_AGE
        logger.warn("Signing key is too new to replace: #{key_age}")
        return nil
      end

      last_request_age = Time.now - get_cached_time(REDIS_UAA_VERIFY_QUERIED_AT)
      if last_request_age < MIN_KEY_ACQUIRE
        logger.warn("Signing key request was just made: #{last_request_age}")
        return nil
      end

      set_cached_time(REDIS_UAA_VERIFY_QUERIED_AT, Time.now)
      key_response = CF::UAA::Misc.validation_key(uaa_config[:url])
      logger.warn "validation_key returned #{key_response.inspect}"
      set_cached_time(REDIS_UAA_VERIFY_SET_AT, Time.now)
      key_response['value']
    end

    def token_format_valid?(auth_token)
      auth_token && auth_token.upcase.start_with?("BEARER")
    end

    def get_cached_verification_key
      redis_client.get(REDIS_UAA_VERIFY_KEY)
    end

    def cache_verification_key(key)
      if key
        redis_client.set(REDIS_UAA_VERIFY_KEY, key)
      else
        redis_client.del(REDIS_UAA_VERIFY_KEY)
      end
    end

    def get_cached_time(key)
      # returns Time.at(0) if value is not set
      Time.at(redis_client.get(key).to_i)
    end

    def set_cached_time(key, time)
      redis_client.set(key, time.to_i)
    end

    def symmetric_key
      uaa_config[:symmetric_secret]
    end

    def uaa_config
      config[:uaa]
    end

    def redis_client
      @redis_client ||= Redis.new(
        :host => config[:redis][:host],
        :port => config[:redis][:port],
        :password => config[:redis][:password]
      )
    end
  end
end
