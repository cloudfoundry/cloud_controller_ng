module UserHelpers
  def set_current_user(user, opts={})
    token_decoder = VCAP::UaaTokenDecoder.new(TestConfig.config)
    header_token = user ? "bearer #{user_token(user, opts)}" : nil
    token_information = opts[:token] ? opts[:token] : token_decoder.decode_token(header_token)
    VCAP::CloudController::SecurityContext.set(user, token_information, header_token)
    user
  end

  # rubocop:disable all
  def set_current_user_as_admin(opts={})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_current_user(user, { admin: true }.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_admin_read_only(opts={})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_current_user(user, { admin_read_only: true }.merge(opts))
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

      if opts[:admin_read_only]
        scopes << 'cloud_controller.admin_read_only'
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

  def allow_user_read_access(user, space:)
    allow(permissions_double(user)).to receive(:can_read_from_space?).with(space.guid, space.organization_guid).and_return(true)
  end

  def allow_user_secret_access(user, space:)
    allow(permissions_double(user)).to receive(:can_see_secrets_in_space?).with(space.guid, space.organization_guid).and_return(true)
  end

  def allow_user_write_access(user, space:)
    allow(permissions_double(user)).to receive(:can_write_to_space?).with(space.guid).and_return(true)
  end

  def disallow_user_read_access(user, space:)
    allow(permissions_double(user)).to receive(:can_read_from_space?).with(space.guid, space.organization_guid).and_return(false)
  end

  def disallow_user_secret_access(user, space:)
    allow(permissions_double(user)).to receive(:can_see_secrets_in_space?).with(space.guid, space.organization_guid).and_return(false)
  end

  def disallow_user_write_access(user, space:)
    allow(permissions_double(user)).to receive(:can_write_to_space?).with(space.guid).and_return(false)
  end

  def stub_readable_space_guids_for(user, space)
    allow(permissions_double(user)).to receive(:readable_space_guids).and_return([space.guid])
  end

  def permissions_double(user)
    @permissions ||= {}
    @permissions[user.guid] ||= begin
      instance_double(VCAP::CloudController::Permissions).tap do |permissions|
        allow(VCAP::CloudController::Permissions).to receive(:new).with(user).and_return(permissions)
      end
    end
  end
end
