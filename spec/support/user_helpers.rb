module UserHelpers
  def set_current_user(user, opts={})
    token_decoder = VCAP::CloudController::UaaTokenDecoder.new(TestConfig.config_instance.get(:uaa))
    header_token = user ? "bearer #{user_token(user, opts)}" : nil
    token_information = opts[:token] || token_decoder.decode_token(header_token)
    VCAP::CloudController::SecurityContext.set(user, token_information, header_token)
    user
  end

  # rubocop:disable all
  def set_current_user_as_admin(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_current_user(user, { admin: true }.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_admin_read_only(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_current_user(user, { admin_read_only: true }.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_global_auditor(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_current_user(user, { global_auditor: true }.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_unauthenticated(opts = {})
    # rubocop:enable all
    set_current_user(nil, opts)
  end

  # rubocop:disable all
  def set_current_user_as_reader_and_writer(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.read cloud_controller.write) }
    set_current_user(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_reader(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.read) }
    set_current_user(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_writer(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.write) }
    set_current_user(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_current_user_as_role(role:, org: nil, space: nil, user: nil, scopes: nil)
    # rubocop:enable all
    current_user = user || VCAP::CloudController::User.make
    current_user = set_current_user(current_user, scopes: scopes)

    scope_roles = %w(admin admin_read_only global_auditor reader_and_writer reader writer)
    if org && !scope_roles.include?(role)
      org.add_user(current_user)
    end

    # rubocop:disable Lint/DuplicateBranch
    case role.to_s
    when 'admin'
      set_current_user_as_admin(user: current_user, scopes: scopes || [])
    when 'admin_read_only'
      set_current_user_as_admin_read_only(user: current_user, scopes: scopes || [])
    when 'global_auditor'
      set_current_user_as_global_auditor(user: current_user, scopes: scopes || [])
    when 'space_developer'
      space.add_developer(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'spaces_application_supporters'
      space.add_application_supporter(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'space_auditor'
      space.add_auditor(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'space_manager'
      space.add_manager(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'org_user'
      nil
    when 'org_auditor'
      org.add_auditor(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'org_billing_manager'
      org.add_billing_manager(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'org_manager'
      org.add_manager(current_user)
      set_current_user_as_reader_and_writer(user: current_user)
    when 'unauthenticated'
      set_current_user_as_unauthenticated
    when 'reader_and_writer'
      set_current_user_as_reader_and_writer(user: current_user)
    when 'reader'
      set_current_user_as_reader(user: current_user)
    when 'writer'
      set_current_user_as_writer(user: current_user)
    when 'no_role'
      nil
    else
      fail("Unknown role '#{role}'")
    end
    # rubocop:enable Lint/DuplicateBranch
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

      if opts[:global_auditor]
        scopes << 'cloud_controller.global_auditor'
      end

      if opts[:update_build_state]
        scopes << 'cloud_controller.update_build_state'
      end

      encoding_opts = {
        user_id: user ? user.guid : (rand * 1_000_000_000).ceil,
        email: opts[:email],
        scope: scopes,
        jti: 'some-valid-jti',
        iss: opts[:iss] || UAAIssuer::ISSUER
      }

      encoding_opts[:user_name] = opts[:user_name] if opts[:user_name]

      encoding_opts[:exp] = 0 if opts[:expired]

      user_token = token_coder.encode(encoding_opts)

      return user_token
    end

    nil
  end

  def client_token(cloud_controller_user, opts={})
    token_coder = CF::UAA::TokenCoder.new(audience_ids: TestConfig.config[:uaa][:resource_id],
      skey: TestConfig.config[:uaa][:symmetric_secret],
      pkey: nil)

    if cloud_controller_user
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

      if opts[:global_auditor]
        scopes << 'cloud_controller.global_auditor'
      end

      encoding_opts = {
        client_id: cloud_controller_user ? cloud_controller_user.guid : (rand * 1_000_000_000).ceil,
        email: opts[:email],
        scope: scopes,
        jti: 'some-valid-jti',
        iss: opts[:iss] || UAAIssuer::ISSUER
      }

      encoding_opts[:user_name] = opts[:user_name] if opts[:user_name]

      encoding_opts[:exp] = 0 if opts[:expired]

      user_token = token_coder.encode(encoding_opts)

      return user_token
    end

    nil
  end

  def allow_user_secret_access(user, space:)
    allow(permissions_double(user)).to receive(:can_read_secrets_in_space?).with(space.guid, space.organization_guid).and_return(true)
  end

  def allow_user_write_access(user, space:)
    allow(permissions_double(user)).to receive(:can_write_to_space?).with(space.guid).and_return(true)
    allow(permissions_double(user)).to receive(:untrusted_can_write_to_space?).with(space.guid).and_return(true)
  end

  def allow_user_read_access_for(user, orgs: [], spaces: [])
    allow(permissions_double(user)).to receive(:can_read_from_org?).and_return(false)
    orgs.each do |org|
      allow(permissions_double(user)).to receive(:can_read_from_org?).with(org.guid).and_return(true)
    end
    stub_readable_org_guids_for(user, orgs)

    allow(permissions_double(user)).to receive(:can_read_from_space?).and_return(false)
    allow(permissions_double(user)).to receive(:untrusted_can_read_from_space?).and_return(false)
    spaces.each do |space|
      allow(permissions_double(user)).to receive(:can_read_from_space?).with(space.guid, space.organization_guid).and_return(true)
      allow(permissions_double(user)).to receive(:untrusted_can_read_from_space?).with(space.guid, space.organization_guid).and_return(true)
    end

    stub_readable_space_guids_for(user, spaces)
  end

  def allow_user_global_read_access(user)
    allow(permissions_double(user)).to receive(:can_read_globally?).and_return(true)
  end

  def allow_user_global_write_access(user)
    allow(permissions_double(user)).to receive(:can_write_globally?).and_return(true)
  end

  def allow_user_read_access_for_isolation_segment(user)
    allow(permissions_double(user)).to receive(:can_read_from_isolation_segment?).and_return(true)
  end

  def disallow_user_read_access_for_isolation_segment(user)
    allow(permissions_double(user)).to receive(:can_read_from_isolation_segment?).and_return(false)
  end

  def disallow_user_global_read_access(user)
    allow(permissions_double(user)).to receive(:can_read_globally?).and_return(false)
  end

  def disallow_user_global_write_access(user)
    allow(permissions_double(user)).to receive(:can_write_globally?).and_return(false)
  end

  def disallow_user_read_access(user, space:)
    allow(permissions_double(user)).to receive(:can_read_from_space?).with(space.guid, space.organization_guid).and_return(false)
    allow(permissions_double(user)).to receive(:untrusted_can_read_from_space?).with(space.guid, space.organization_guid).and_return(false)
  end

  def disallow_user_build_update_access(user)
    allow(permissions_double(user)).to receive(:can_update_build_state?).and_return(false)
  end

  def disallow_user_secret_access(user, space:)
    allow(permissions_double(user)).to receive(:can_read_secrets_in_space?).with(space.guid, space.organization_guid).and_return(false)
  end

  def disallow_user_write_access(user, space:)
    allow(permissions_double(user)).to receive(:can_write_to_space?).with(space.guid).and_return(false)
    allow(permissions_double(user)).to receive(:untrusted_can_write_to_space?).with(space.guid).and_return(false)
  end

  def stub_readable_space_guids_for(user, spaces)
    allow(permissions_double(user)).to receive(:readable_space_guids).and_return(spaces.map(&:guid))
    allow(permissions_double(user)).to receive(:readable_application_supporter_space_guids).and_return(spaces.map(&:guid))
  end

  def stub_readable_org_guids_for(user, orgs)
    allow(permissions_double(user)).to receive(:readable_org_guids).and_return(orgs.map(&:guid))
  end

  def allow_user_perm_permission(permission, space_guid:, org_guid:)
    allow(perm_permissions_double(user)).to receive(permission).and_return(false)
    allow(perm_permissions_double(user)).to receive(permission).with(space_guid: space_guid, org_guid: org_guid).and_return(true)
  end

  def allow_user_perm_permission_for(method, visible_guids: [])
    allow(perm_permissions_double(user)).to receive(method).and_return(visible_guids)
  end

  def permissions_double(user)
    @permissions ||= {}
    @permissions[user.guid] ||= instance_double(VCAP::CloudController::Permissions).tap do |permissions|
      allow(VCAP::CloudController::Permissions).to receive(:new).with(user).and_return(permissions)
      allow(permissions).to receive(:can_read_globally?).and_return(false)
    end
  end

  def perm_permissions_double(user)
    @perm_permissions ||= {}
    @perm_permissions[user.guid] ||= instance_double(VCAP::CloudController::Perm::Permissions).tap do |permissions|
      allow(VCAP::CloudController::Perm::Permissions).to receive(:new).
        with(user_id: user.guid, perm_client: anything, issuer: anything, roles: anything).
        and_return(permissions)
      allow(permissions).to receive(:can_read_globally?).and_return(false)
    end
  end
end
