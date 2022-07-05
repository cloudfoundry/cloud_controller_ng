module SpaceRestrictedResponseGenerators
  def self.default_permitted_roles
    %w(
      admin
      admin_read_only
      global_auditor
      space_developer
      space_manager
      space_auditor
      space_supporter
      org_manager
    )
  end

  def self.default_write_permitted_roles
    %w(
      admin
      space_developer
    )
  end

  def self.org_suspended_permitted_roles
    %w(
      admin
    )
  end

  def self.default_suspended_roles
    %w(
      space_developer
    )
  end

  def self.forbidden_response
    [{
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }]
  end

  def self.suspended_response
    [{
      'detail' => 'The organization is suspended',
      'title' => 'CF-OrgSuspended',
      'code' => 10017,
    }]
  end

  def responses_for_space_restricted_single_endpoint(response_object, permitted_roles: nil)
    permitted_roles ||= SpaceRestrictedResponseGenerators.default_permitted_roles

    Hash.new(code: 404).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 200, response_object: response_object }
      end
    end
  end

  def responses_for_space_restricted_create_endpoint(success_code:, permitted_roles: nil)
    permitted_roles ||= SpaceRestrictedResponseGenerators.default_write_permitted_roles

    Hash.new(code: 403, errors: SpaceRestrictedResponseGenerators.forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 422 } # TODO: status code 422 for 'no_role' is not correct for all endpoints
      end
    end
  end

  def responses_for_space_restricted_update_endpoint(success_code:, success_body: nil)
    permitted_roles = SpaceRestrictedResponseGenerators.default_write_permitted_roles

    Hash.new(code: 403, errors: SpaceRestrictedResponseGenerators.forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code, response_object: success_body }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 404 }
      end
    end
  end

  def responses_for_org_suspended_space_restricted_create_endpoint(success_code:, suspended_roles: nil)
    permitted_roles = SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
    suspended_roles ||= SpaceRestrictedResponseGenerators.default_suspended_roles

    Hash.new(code: 403, errors: SpaceRestrictedResponseGenerators.forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      suspended_roles.each do |role|
        h[role] = { code: 403, errors: SpaceRestrictedResponseGenerators.suspended_response }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 422 } # TODO: status code 422 for 'no_role' is not correct for all endpoints
      end
    end
  end

  def responses_for_org_suspended_space_restricted_update_endpoint(success_code:)
    permitted_roles = SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
    suspended_roles = SpaceRestrictedResponseGenerators.default_suspended_roles

    Hash.new(code: 403, errors: SpaceRestrictedResponseGenerators.forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      suspended_roles.each do |role|
        h[role] = { code: 403, errors: SpaceRestrictedResponseGenerators.suspended_response }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 404 }
      end
    end
  end

  def responses_for_org_suspended_space_restricted_delete_endpoint(success_code:, suspended_roles: nil)
    permitted_roles = SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
    suspended_roles ||= SpaceRestrictedResponseGenerators.default_suspended_roles

    Hash.new(code: 403, errors: SpaceRestrictedResponseGenerators.forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      suspended_roles.each do |role|
        h[role] = { code: 403, errors: SpaceRestrictedResponseGenerators.suspended_response }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 404 }
      end
    end
  end

  def responses_for_space_restricted_delete_endpoint(permitted_roles: nil)
    permitted_roles ||= SpaceRestrictedResponseGenerators.default_write_permitted_roles

    Hash.new(code: 403).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 204 }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 404 }
      end
    end
  end

  def responses_for_space_restricted_async_delete_endpoint(permitted_roles: nil)
    permitted_roles ||= SpaceRestrictedResponseGenerators.default_write_permitted_roles

    Hash.new(code: 403).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 202 }
      end
      %w[no_role org_auditor org_billing_manager].each do |role|
        h[role] = { code: 404 }
      end
    end
  end
end
