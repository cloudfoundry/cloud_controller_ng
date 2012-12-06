require "uaa/misc"

module VCAP
  module UaaUtil
    MIN_KEY_AGE = 600

    def apply_token(auth_token, resource_id, symmetric_secret, target)
      return unless auth_token && auth_token.upcase.start_with?("BEARER")

      key = @verification_key
      key ||= get_verification_key(target)

      begin
        token_coder = CF::UAA::TokenCoder.new(:audience_ids => resource_id,
                                              :skey => symmetric_secret,
                                              :pkey => key)
        token_information = token_coder.decode(auth_token)
        logger.info("Token received from the UAA #{token_information.inspect}")

        yield(token_information)
        @verification_key = key if token_information # cache working key

      rescue CF::UAA::DecodeError => e
        # todo: there should be a CF::UAA exception providing this granularity
        raise unless e.to_s == 'Signature verification failed'

        key = get_verification_key(target)
        if key != @verification_key
          logger.warn "#{auth_token} failed #{@verification_key}; try #{key}"
          retry
        end
        raise
      end
    end

    def get_verification_key(target)
      # do not hit UAA for every failed token or blank key
      # (at most once every MIN_KEY_AGE period)
      # return the last known working key instead
      @verification_key_timestamp ||= Time.new(0)
      return @verification_key if Time.now - @verification_key_timestamp < MIN_KEY_AGE

      key_response = CF::UAA::Misc.validation_key(target)
      logger.warn "validation_key returned #{key_response.inspect}"
      @verification_key_timestamp = Time.now
      key_response['value']

    rescue CF::UAA::TargetError => e
      # todo: there should also be a more specific exception here
      # unauthorized indicates uaa is running in symmetric key mode
      raise unless e.info['error'] == 'unauthorized'

      return nil
    end

  end
end
