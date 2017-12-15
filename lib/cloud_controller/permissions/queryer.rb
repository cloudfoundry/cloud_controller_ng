class VCAP::CloudController::Permissions::Queryer
  attr_reader :perm_permissions, :db_permissions

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

    self.new(
      db_permissions: db_permissions,
      perm_permissions: perm_permissions,
      perm_enabled: perm_enabled,
      query_enabled: query_enabled,
      current_user_guid: security_context.current_user_guid
    )
  end

  def initialize(db_permissions:, perm_permissions:, perm_enabled:, query_enabled:, current_user_guid:)
    @db_permissions = db_permissions
    @perm_permissions = perm_permissions
    @enabled = perm_enabled && query_enabled
    @current_user_guid = current_user_guid
  end

  def can_read?(space_guid, org_guid)
    science 'can_read_from_space?' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid, action: 'space.read')
      e.use { db_permissions.can_read_from_space?(space_guid, org_guid) }
      e.try { perm_permissions.can_read_from_space?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_write_to_org?(org_guid)
    science 'can_write_to_org?' do |e|
      e.context(org_guid: org_guid, action: 'org.write')
      e.use { db_permissions.can_write_to_org?(org_guid) }
      e.try { perm_permissions.can_write_to_org?(org_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def can_read_from_org?(org_guid)
    science 'can_read_from_org?' do |e|
      e.context(org_guid: org_guid, action: 'org.read')
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
      e.context(isolation_segment_guid: isolation_segment.guid, action: 'isolation_segment.read')
      e.use { db_permissions.can_read_from_isolation_segment?(isolation_segment) }
      e.try { perm_permissions.can_read_from_isolation_segment?(isolation_segment) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_see_secrets?(space)
    science 'can_see_secrets_in_space?' do |e|
      e.context(space_guid: space.guid, org_guid: space.organization.guid, action: 'space.read_secrets')
      e.use { db_permissions.can_see_secrets_in_space?(space.guid, space.organization.guid) }
      e.try { perm_permissions.can_see_secrets_in_space?(space.guid, space.organization.guid) }

      e.run_if { !db_permissions.can_read_secrets_globally? }
    end
  end

  def can_write?(space_guid)
    science 'can_write_to_space?' do |e|
      e.context(space_guid: space_guid, action: 'space.write')
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

  attr_reader :enabled, :current_user_guid

  def science(name)
    experiment = VCAP::CloudController::Science::Experiment.new(name: name, enabled: enabled)
    experiment.context(current_user_guid: current_user_guid)
    yield experiment
    experiment.run
  end
end
