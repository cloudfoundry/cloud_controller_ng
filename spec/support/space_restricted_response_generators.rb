module SpaceRestrictedResponseGenerators
  def self.default_permitted_roles
    %w(
      admin
      admin_read_only
      global_auditor
      space_developer
      space_manager
      space_auditor
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

  def responses_for_space_restricted_single_endpoint(
    response_object,
    permitted_roles: SpaceRestrictedResponseGenerators.default_permitted_roles
  )
    Hash.new(code: 404).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 200, response_object: response_object }
      end
    end
  end

  def responses_for_space_restricted_create_endpoint(
    success_code: 202,
    permitted_roles: SpaceRestrictedResponseGenerators.default_write_permitted_roles
  )
    forbidden_response =       {
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }

    Hash.new({ code: 403, response_object: forbidden_response }).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      h['no_role'] = { code: 422 } # TODO: this is not correct for all endpoints
      h['org_auditor'] = { code: 422 }
      h['org_billing_manager'] = { code: 422 }
    end
  end

  def responses_for_space_restricted_update_endpoint(
    success_code: 202,
    permitted_roles: SpaceRestrictedResponseGenerators.default_write_permitted_roles
  )
    forbidden_response =       {
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }

    Hash.new({ code: 403, response_object: forbidden_response }).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      h['no_role'] = { code: 404 }
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
    end
  end

  def responses_for_org_suspended_space_restricted_create_endpoint(
    success_code: 202,
    permitted_roles: SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
  )
    forbidden_response =       {
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }

    Hash.new({ code: 403, response_object: forbidden_response }).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      h['no_role'] = { code: 422 } # TODO: this is not correct for all endpoints
      h['org_auditor'] = { code: 422 }
      h['org_billing_manager'] = { code: 422 }
    end
  end

  def responses_for_org_suspended_space_restricted_update_endpoint(
    success_code: 202,
    permitted_roles: SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
  )
    forbidden_response =       {
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }
    Hash.new(code: 403, response_object: forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      h['no_role'] = { code: 404 }
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
    end
  end

  def responses_for_org_suspended_space_restricted_delete_endpoint(
    success_code: 202,
    permitted_roles: SpaceRestrictedResponseGenerators.org_suspended_permitted_roles
  )
    forbidden_response =       {
      'detail' => 'You are not authorized to perform the requested action',
      'title' => 'CF-NotAuthorized',
      'code' => 10003,
    }
    Hash.new(code: 403, response_object: forbidden_response).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: success_code }
      end
      h['no_role'] = { code: 404 }
      h['org_auditor'] = { code: 404 }
      h['org_billing_manager'] = { code: 404 }
    end
  end

  def responses_for_space_restricted_delete_endpoint(
    permitted_roles: SpaceRestrictedResponseGenerators.default_write_permitted_roles
    )
    Hash.new(code: 403).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 204 }
      end
      h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = { code: 404 }
    end
  end

  def responses_for_space_restricted_async_delete_endpoint(
    permitted_roles: SpaceRestrictedResponseGenerators.default_write_permitted_roles
  )
    Hash.new(code: 403).tap do |h|
      permitted_roles.each do |role|
        h[role] = { code: 202 }
      end
      h['org_billing_manager'] = h['org_auditor'] = h['no_role'] = { code: 404 }
    end
  end
end
