class VCAP::CloudController::Permissions::Queryer
  def self.build(perm_client, statsd_client, security_context, perm_enabled, query_raise_on_mismatch=false)
    VCAP::CloudController::Science::Experiment.raise_on_mismatches = query_raise_on_mismatch

    db_permissions =
      VCAP::CloudController::Permissions.new(
        security_context.current_user
      )

    perm_permissions = VCAP::CloudController::Perm::Permissions.new(
      perm_client: perm_client,
      roles: security_context.roles,
      user_id: security_context.current_user_guid,
      issuer: security_context.issuer,
    )

    self.new(
      db_permissions: db_permissions,
      perm_permissions: perm_permissions,
      statsd_client: statsd_client,
      perm_enabled: perm_enabled,
      current_user_guid: security_context.current_user_guid
    )
  end

  def initialize(db_permissions:, perm_permissions:, statsd_client:, perm_enabled:, current_user_guid:)
    @db_permissions = db_permissions
    @perm_permissions = perm_permissions
    @statsd_client = statsd_client
    @enabled = perm_enabled
    @current_user_guid = current_user_guid
  end

  def can_read_globally?
    science 'can_read_globally' do |e|
      e.use { db_permissions.can_read_globally? }
      e.try { perm_permissions.can_read_globally? }

      e.run_if { false }
    end
  end

  def can_write_globally?
    science 'can_write_globally' do |e|
      e.use { db_permissions.can_write_globally? }
      e.try { perm_permissions.can_write_globally? }

      e.run_if { false }
    end
  end

  def can_read_secrets_globally?
    science 'can_read_secrets_globally' do |e|
      e.use { db_permissions.can_read_secrets_globally? }
      e.try { perm_permissions.can_read_secrets_globally? }

      e.run_if { false }
    end
  end

  def readable_org_guids
    science 'readable_org_guids' do |e|
      e.use { db_permissions.readable_org_guids }
      e.try { perm_permissions.readable_org_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_org_guids_for_domains
    science 'readable_org_guids_for_domains' do |e|
      e.use do
        db_permissions.readable_org_guids_for_domains
      end
      e.try do
        perm_permissions.readable_org_guids_for_domains
      end

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_org_contents_org_guids
    science 'readable_org_contents_org_guids' do |e|
      e.use do
        db_permissions.readable_org_contents_org_guids
      end
      e.try do
        perm_permissions.readable_org_contents_org_guids
      end

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_read_from_org?(org_guid)
    science 'can_read_from_org' do |e|
      e.context(org_guid: org_guid)
      e.use { db_permissions.can_read_from_org?(org_guid) }
      e.try { perm_permissions.can_read_from_org?(org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_write_to_org?(org_guid)
    science 'can_write_to_org' do |e|
      e.context(org_guid: org_guid)
      e.use { db_permissions.can_write_to_org?(org_guid) }
      e.try { perm_permissions.can_write_to_org?(org_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def readable_space_guids
    science 'readable_space_guids' do |e|
      e.use { db_permissions.readable_space_guids }
      e.try { perm_permissions.readable_space_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_read_from_space?(space_guid, org_guid)
    science 'can_read_from_space' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid)
      e.use { db_permissions.can_read_from_space?(space_guid, org_guid) }
      e.try { perm_permissions.can_read_from_space?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_read_secrets_in_space?(space_guid, org_guid)
    science 'can_read_secrets_in_space' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid)
      e.use { db_permissions.can_read_secrets_in_space?(space_guid, org_guid) }
      e.try { perm_permissions.can_read_secrets_in_space?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_read_secrets_globally? }
    end
  end

  def can_write_to_space?(space_guid)
    science 'can_write_to_space' do |e|
      e.context(space_guid: space_guid)
      e.use { db_permissions.can_write_to_space?(space_guid) }
      e.try { perm_permissions.can_write_to_space?(space_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def can_update_space?(space_guid, org_guid)
    science 'can_update_space' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid)
      e.use { db_permissions.can_update_space?(space_guid, org_guid) }
      e.try { perm_permissions.can_update_space?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_write_globally? }
    end
  end

  def can_read_from_isolation_segment?(isolation_segment)
    science 'can_read_from_isolation_segment' do |e|
      e.context(isolation_segment_guid: isolation_segment.guid)
      e.use { db_permissions.can_read_from_isolation_segment?(isolation_segment) }
      e.try { perm_permissions.can_read_from_isolation_segment?(isolation_segment) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_route_dataset
    db_permissions.readable_route_dataset
  end

  def readable_route_guids
    science 'readable_route_guids' do |e|
      e.use { db_permissions.readable_route_guids }
      e.try { perm_permissions.readable_route_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_read_route?(space_guid, org_guid)
    science 'can_read_route' do |e|
      e.context(space_guid: space_guid, org_guid: org_guid)
      e.use { db_permissions.can_read_route?(space_guid, org_guid) }
      e.try { perm_permissions.can_read_route?(space_guid, org_guid) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_app_guids
    science 'readable_app_guids' do |e|
      e.use { db_permissions.readable_app_guids }
      e.try { perm_permissions.readable_app_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_secret_space_guids
    science 'readable_secret_space_guids' do |e|
      e.use { db_permissions.readable_secret_space_guids }
      e.try { perm_permissions.readable_secret_space_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_read_service_broker?(service_broker)
    can_read_globally? || can_read_space_scoped_service_broker?(service_broker)
  end

  def can_read_space_scoped_service_broker?(service_broker)
    service_broker.space_scoped? &&
        can_read_secrets_in_space?(service_broker.space_guid, service_broker.space.organization_guid)
  end

  def can_write_global_service_broker?
    can_write_globally?
  end

  def can_write_space_scoped_service_broker?(space_guid)
    can_write_to_space?(space_guid)
  end

  def readable_route_mapping_guids
    science 'readable_route_mapping_guids' do |e|
      e.use { db_permissions.readable_route_mapping_guids }
      e.try { perm_permissions.readable_route_mapping_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def task_readable_space_guids
    perm_permissions.task_readable_space_guids
  end

  def can_read_task?(org_guid:, space_guid:)
    perm_permissions.can_read_task?(org_guid: org_guid, space_guid: space_guid)
  end

  def readable_space_scoped_space_guids
    science 'readable_space_scoped_space_guids' do |e|
      e.use { db_permissions.readable_space_scoped_space_guids }
      e.try { perm_permissions.readable_space_scoped_space_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_space_quota_guids
    science 'readable_space_quota_guids' do |e|
      e.use { db_permissions.readable_space_quota_guids }
      e.try { perm_permissions.readable_space_quota_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def readable_security_group_guids
    science 'readable_security_group_guids' do |e|
      e.use { db_permissions.readable_security_group_guids }
      e.try { perm_permissions.readable_security_group_guids }

      e.compare { |a, b| compare_arrays(a, b) }

      e.run_if { !db_permissions.can_read_globally? }
    end
  end

  def can_update_build_state?
    db_permissions.can_update_build_state?
  end

  private

  attr_reader :perm_permissions, :db_permissions, :statsd_client, :enabled, :current_user_guid

  def science(name)
    experiment = VCAP::CloudController::Science::Experiment.new(
      statsd_client: statsd_client,
      name: name,
      enabled: enabled,
    )
    experiment.context(current_user_guid: current_user_guid)
    yield experiment
    experiment.run
  end

  def compare_arrays(left, right)
    if left.is_a?(Array) && right.is_a?(Array)
      left.sort == right.sort
    else
      left == right
    end
  end
end
