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
        uaa_id = token_information['user_id'] if token_information
        user = VCAP::CloudController::Models::User.find(:guid => uaa_id) if uaa_id

        # Bootstraping mechanism
        #
        # TODO: replace this with an external bootstrapping mechanism.
        # I'm not wild about having *any* auto-admin generation code
        # in the cc.
        # TODO: set admin to false here to make sure everyone provides admin scope
        if (user.nil? && VCAP::CloudController::Models::User.count == 0 &&
            @config[:bootstrap_admin_email] && token_information['email'] &&
            @config[:bootstrap_admin_email] == token_information['email'])
          user = VCAP::CloudController::Models::User.create(:guid => uaa_id,
                                     :admin => true, :active => true)
        end

        yield(user, token_information)
        @verification_key = key if token_information # cache working key

      rescue CF::UAA::DecodeError => e
        # todo: there should be a CF:UAA exception providing this granularity
        raise unless e.to_s == 'Signature verification failed'

        # do not hit UAA for every failed token
        # (at most once every MIN_KEY_AGE period)
        @verification_key_timestamp ||= Time.new(0)
        if Time.now - @verification_key_timestamp >= MIN_KEY_AGE
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
