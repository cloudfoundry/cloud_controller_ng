module UserHeaderHelpers
  def base_json_headers(headers={})
    headers.merge({ 'CONTENT_TYPE' => 'application/json' })
  end

  def set_user_with_header(user, opts={})
    opts = {
      email: Sham.email,
      user_name: Sham.name,
      https: false
    }.merge(opts)

    headers = {}
    headers['HTTP_AUTHORIZATION'] = "bearer #{generate_user_token(user, opts)}"
    headers['HTTP_X_FORWARDED_PROTO'] = 'https' if opts[:https]
    base_json_headers(headers)
  end

  # rubocop:disable all
  def set_user_with_header_as_admin(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_user_with_header(user, { admin: true }.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_admin_read_only(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_user_with_header(user, { admin_read_only: true }.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_global_auditor(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    set_user_with_header(user, { global_auditor: true }.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_unauthenticated(opts = {})
    # rubocop:enable all
    set_user_with_header(nil, opts)
  end

  # rubocop:disable all
  def set_user_with_header_as_reader_and_writer(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.read cloud_controller.write) }
    set_user_with_header(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_reader(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.read) }
    set_user_with_header(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_writer(opts = {})
    # rubocop:enable all
    user = opts.delete(:user) || VCAP::CloudController::User.make
    scopes = { scopes: %w(cloud_controller.write) }
    set_user_with_header(user, scopes.merge(opts))
  end

  # rubocop:disable all
  def set_user_with_header_as_role(role:, org: nil, space: nil, user: nil, scopes: nil, user_name: nil, email: nil)
    # rubocop:enable all
    current_user = user || VCAP::CloudController::User.make

    scope_roles = %w(admin admin_read_only global_auditor reader_and_writer reader writer)
    if org && !scope_roles.include?(role) && role.to_s != 'no_role'
      org.add_user(current_user)
    end

    # rubocop:disable Lint/DuplicateBranch
    case role.to_s
    when 'admin'
      set_user_with_header_as_admin(user: current_user, scopes: scopes || ['cloud_controller.write'], user_name: user_name, email: email)
    when 'admin_read_only'
      set_user_with_header_as_admin_read_only(user: current_user, scopes: scopes || ['cloud_controller.write'], user_name: user_name, email: email)
    when 'global_auditor'
      set_user_with_header_as_global_auditor(user: current_user, scopes: scopes || ['cloud_controller.write'], user_name: user_name, email: email)
    when 'space_developer'
      space.add_developer(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'space_auditor'
      space.add_auditor(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'space_manager'
      space.add_manager(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'org_user'
      set_user_with_header(user, user_name: user_name, email: email)
    when 'org_auditor'
      org.add_auditor(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'org_billing_manager'
      org.add_billing_manager(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'org_manager'
      org.add_manager(current_user)
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'unauthenticated'
      set_user_with_header_as_unauthenticated
    when 'reader_and_writer'
      set_user_with_header_as_reader_and_writer(user: current_user, user_name: user_name, email: email)
    when 'reader'
      set_user_with_header_as_reader(user: current_user, user_name: user_name, email: email)
    when 'writer'
      set_user_with_header_as_writer(user: current_user, user_name: user_name, email: email)
    when 'no_role' # not a real role - added for testing
      set_user_with_header(user, user_name: user_name, email: email)
    else
      fail("Unknown role '#{role}'")
    end
    # rubocop:enable Lint/DuplicateBranch
  end

  # rubocop:disable all
  def generate_user_token(user, opts={})
    token_coder = CF::UAA::TokenCoder.new(
      audience_ids: TestConfig.config[:uaa][:resource_id],
      skey: TestConfig.config[:uaa][:symmetric_secret],
      pkey: nil)

    if user
      scopes = opts[:scopes]
      if scopes.nil? && !opts[:admin] && !opts[:admin_read_only] && !opts[:global_auditor]
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
end
