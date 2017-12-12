class VCAP::CloudController::Permissions::Queryer
  attr_reader :perm_permissions, :db_permissions, :query_enabled, :perm_enabled, :current_user_guid

  def self.build_from_config(configuration, file_reader, security_context)
    db_permissions =
      VCAP::CloudController::Permissions.new(
        security_context.current_user
      )

    perm_client = VCAP::CloudController::Perm::Client.build_from_config(configuration, file_reader)
    perm_permissions = VCAP::CloudController::Perm::Permissions.new(
      perm_client: perm_client,
      roles: security_context.roles,
      user_id: security_context.current_user_guid,
      issuer: security_context.token['iss'],
    )

    perm_enabled = configuration.get(:perm, :enabled)
    query_enabled = configuration.get(:perm, :query_enabled)

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
    @perm_enabled = perm_enabled
    @query_enabled = query_enabled
    @current_user_guid = current_user_guid
  end

  private

  def science(name)
    experiment = VCAP::CloudController::Perm::Experiment.new(name: name, perm_enabled: perm_enabled, query_enabled: query_enabled)
    experiment.context(current_user_guid: current_user_guid)

    yield experiment
    experiment.run
  end
end
