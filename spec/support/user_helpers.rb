module UserHelpers
  def set_current_user(user, opts={})
    token_decoder = VCAP::UaaTokenDecoder.new(TestConfig.config[:uaa])
    header_token = user ? "bearer #{user_token(user, opts)}" : nil
    token_information = opts[:token] ? opts[:token] : token_decoder.decode_token(header_token)
    VCAP::CloudController::SecurityContext.set(user, token_information, header_token)
  end

  def user_token(user, opts={})
    token_coder = CF::UAA::TokenCoder.new(audience_ids: TestConfig.config[:uaa][:resource_id],
                                          skey: TestConfig.config[:uaa][:symmetric_secret],
                                          pkey: nil)

    if user
      scopes = opts[:scopes]
      if scopes.nil?
        scopes = %w(cloud_controller.read cloud_controller.write)
      end

      if opts[:admin]
        scopes << 'cloud_controller.admin'
      end

      user_token = token_coder.encode(
        user_id: user ? user.guid : (rand * 1_000_000_000).ceil,
        email:   opts[:email],
        scope:   scopes
      )

      return user_token
    end

    nil
  end
end
