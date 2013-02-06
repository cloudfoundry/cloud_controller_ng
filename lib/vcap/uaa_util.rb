require "uaa/misc"

module VCAP
  module UaaUtil
    # a working key should not be considered for replacement in this period (seconds)
    MIN_KEY_AGE = 600

    # only one request should be attempted within this period (seconds)
    MIN_KEY_ACQUIRE = 20

    # redis keys for persistent data
    REDIS_UAA_VERIFY_KEY = 'cc.verification_key'.freeze
    REDIS_UAA_VERIFY_QUERIED_AT = 'cc.verification_queried_at'.freeze
    REDIS_UAA_VERIFY_SET_AT = 'cc.verification_set_at'.freeze

    def decode_token(auth_token, resource_id, symmetric_secret, target)
      return unless token_format_valid?(auth_token)

      @verification_key = @redis_client.get(REDIS_UAA_VERIFY_KEY) || config[:uaa][:verification_key]
      key = @verification_key
      key ||= get_verification_key(target)

      begin
        token_coder = CF::UAA::TokenCoder.new(
          :audience_ids => resource_id,
          :skey => symmetric_secret,
          :pkey => key
        )
        token_information = token_coder.decode(auth_token)
        logger.info("Token received from the UAA #{token_information.inspect}")

        if token_information
          if key
            @redis_client.set(REDIS_UAA_VERIFY_KEY, key)
          else
            @redis_client.del(REDIS_UAA_VERIFY_KEY)
          end
        end

        token_information
      rescue CF::UAA::InvalidSignature => e
        key = get_verification_key(target)
        if key != @verification_key
          logger.warn "#{auth_token} failed with #{@verification_key}; try #{key}"
          retry
        end
        raise
      end
    end

    def get_verification_key(target)
      new_key = nil

      # do not hit UAA for every failed token or blank key
      # (at most once every MIN_KEY_AGE period)
      # return the last known working key instead
      @verification_key_timestamp ||= redis_get_time(REDIS_UAA_VERIFY_SET_AT)
      key_age = Time.now - @verification_key_timestamp
      if key_age < MIN_KEY_AGE
        logger.warn("Signing key is too new to replace: #{key_age}")
        return @verification_key
      end

      # skip UAA query if one was recently attempted
      @verification_key_attempt ||= redis_get_time(REDIS_UAA_VERIFY_QUERIED_AT)
      last_request_age = Time.now - @verification_key_attempt
      if last_request_age < MIN_KEY_ACQUIRE
        logger.warn("Signing key request was just made: #{last_request_age}")
        return @verification_key
      end

      redis_set_time(REDIS_UAA_VERIFY_QUERIED_AT, Time.now)

      begin
        key_response = CF::UAA::Misc.validation_key(target)
        logger.warn "validation_key returned #{key_response.inspect}"
        new_key = key_response['value']
      rescue CF::UAA::TargetError => e
        raise unless e.info['error'] == 'unauthorized'
      end

      redis_set_time(REDIS_UAA_VERIFY_SET_AT, Time.now)

      new_key
    end

    def token_format_valid?(auth_token)
      auth_token && auth_token.upcase.start_with?("BEARER")
    end

    def redis_get_time(key)
      # returns Time.at(0) if value is not set
      Time.at(@redis_client.get(key).to_i)
    end

    def redis_set_time(key, time)
      @redis_client.set(key, time.to_i)
    end
  end
end
