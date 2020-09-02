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
end
