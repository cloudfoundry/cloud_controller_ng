module VCAP
  module UaaUtil
    MIN_KEY_AGE = 600

    attr_accessor :verification_key_timestamp, :verification_key

    def apply_token(auth_token, resource_id, symmetric_secret, target)
      return unless auth_token && auth_token.upcase.start_with?("BEARER")

      key = @verification_key
      key ||= get_verification_key(target)

      begin
        token_coder = CF::UAA::TokenCoder.new(resource_id,
                                              symmetric_secret,
                                              key)
        token_information = token_coder.decode(auth_token)
        logger.info("Token received from the UAA #{token_information.inspect}")

        yield(token_information)
        @verification_key = key if token_information # cache working key

      rescue CF::UAA::DecodeError => e
        # todo: there should be a CF::UAA exception providing this granularity
        raise unless e.to_s == 'Signature verification failed'

        # do not hit UAA for every failed token
        # (at most once every MIN_KEY_AGE period)
        @verification_key_timestamp ||= Time.new(0)
        if Time.now - @verification_key_timestamp >= MIN_KEY_AGE
          logger.warn "getting a new key from #{target} to replace #{key}"
          key = get_verification_key(target)
          @verification_key_timestamp = Time.now
          if key != @verification_key
            logger.warn "reverifying #{auth_token} with #{key} after #{@verification_key} failed"
            retry
          end
        end
        raise
      end
    end

    def get_verification_key(target)
      key_response = CF::UAA::Misc.validation_key(target)
      logger.warn "validation_key returned #{key_response.inspect}"
      key_response['value']
    end

  end
end
