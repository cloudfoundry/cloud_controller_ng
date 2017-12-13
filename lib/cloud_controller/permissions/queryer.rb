class VCAP::CloudController::Permissions::Queryer
  attr_reader :perm_permissions, :db_permissions, :experiment_builder

  def self.build(perm_client, security_context, perm_enabled, query_enabled)
    db_permissions =
      VCAP::CloudController::Permissions.new(
        security_context.current_user
      )

    perm_permissions = VCAP::CloudController::Perm::Permissions.new(
      perm_client: perm_client,
      roles: security_context.roles,
      user_id: security_context.current_user_guid,
      issuer: security_context.token['iss'],
    )

    experiment_builder = ->(name) {
      experiment = VCAP::CloudController::Perm::Experiment.new(name: name, perm_enabled: perm_enabled, query_enabled: query_enabled)
      experiment.context(current_user_guid: security_context.current_user_guid)

      return experiment
    }

    self.new(
      db_permissions: db_permissions,
      perm_permissions: perm_permissions,
      experiment_builder: experiment_builder
    )
  end

  def initialize(db_permissions:, perm_permissions:, experiment_builder:)
    @db_permissions = db_permissions
    @perm_permissions = perm_permissions
    @experiment_builder = experiment_builder
  end

  def can_read?(space_guid, org_guid)
    science 'can_read_from_space?' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid)
      e.use { db_permissions.can_read_from_space?(space_guid, org_guid) }
      e.try { perm_permissions.can_read_from_space?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_write_to_org?(org_guid)
    science 'can_write_to_org?' do |e|
      e.context(org_guid: org_guid)
      e.use { db_permissions.can_write_to_org?(org_guid) }
      e.try { perm_permissions.can_write_to_org?(org_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def can_read_from_org?(org_guid)
    science 'can_read_from_org?' do |e|
      e.context(org_guid: org_guid)
      e.use { db_permissions.can_read_from_org?(org_guid) }
      e.try { perm_permissions.can_read_from_org?(org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_write_globally?
    science 'can_write_globally?' do |e|
      e.use { db_permissions.can_write_globally? }
      e.try { perm_permissions.can_write_globally? }

      e.run_if { false }
    end
  end

  def can_read_globally?
    science 'can_read_globally?' do |e|
      e.use { db_permissions.can_read_globally? }
      e.try { perm_permissions.can_read_globally? }

      e.run_if { false }
    end
  end

  def can_read_from_isolation_segment?(isolation_segment)
    science 'can_read_from_isolation_segment?' do |e|
      e.context(isolation_segment_guid: isolation_segment.guid)
      e.use { db_permissions.can_read_from_isolation_segment?(isolation_segment) }
      e.try { perm_permissions.can_read_from_isolation_segment?(isolation_segment) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_see_secrets?(space)
    science 'can_see_secrets_from_space?' do |e|
      e.context(space_guid: space.guid, org_guid: space.organization.guid)
      e.use { db_permissions.can_see_secrets_in_space?(space.guid, space.organization.guid) }
      e.try { perm_permissions.can_see_secrets_in_space?(space.guid, space.organization.guid) }

      e.run_if { !db_permissions.can_read_secrets_globally? }
    end
  end

  def can_write?(space_guid)
    science 'can_write_to_space?' do |e|
      e.context(space_guid: space_guid)
      e.use { db_permissions.can_write_to_space?(space_guid) }
      e.try { perm_permissions.can_write_to_space?(space_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def readable_space_guids
    science 'readable_space_guids' do |e|
      e.use { db_permissions.readable_space_guids }
    end
  end

  def readable_org_guids
    science 'readable_org_guids' do |e|
      e.use { db_permissions.readable_org_guids }
    end
  end

  private

  def science(name)
    experiment = experiment_builder.call(name)
    yield experiment
    experiment.run
  end
end
