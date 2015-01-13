Sequel.migration do
  TABLE_NAMES = %w(
    app_events
    app_usage_events
    apps
    apps_v3
    billing_events
    buildpacks
    delayed_jobs
    domains
    droplets
    env_groups
    events
    feature_flags
    organizations
    quota_definitions
    routes
    security_groups
    service_auth_tokens
    service_bindings
    service_brokers
    service_dashboard_clients
    service_instances
    service_plan_visibilities
    service_plans
    service_usage_events
    services
    space_quota_definitions
    spaces
    stacks
    users
  )

  up do
    if self.class.name.match /mysql/i
      TABLE_NAMES.each do |table|
        run <<-SQL
        ALTER TABLE #{table} MODIFY created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;
        SQL
      end
    end
  end

  down do
    if self.class.name.match /mysql/i
      TABLE_NAMES.each do |table|
        run <<-SQL
        ALTER TABLE #{table} MODIFY created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;
        SQL
      end
    end
  end
end
