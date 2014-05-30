class Tables
  def initialize(db)
    @db = db
  end

  def counts
    tables_to_verify = %w(
        app_events
        app_usage_events
        apps
        apps_routes
        billing_events
        buildpacks
        delayed_jobs
        domains
        droplets
        events
        organizations
        organizations_auditors
        organizations_billing_managers
        organizations_managers
        organizations_users
        quota_definitions
        routes
        service_auth_tokens
        service_bindings
        service_brokers
        service_dashboard_clients
        service_instances
        service_plan_visibilities
        service_plans
        service_usage_events
        services
        spaces
        spaces_auditors
        spaces_developers
        spaces_managers
        stacks
        tasks
        users
      ).map(&:to_sym)

    tables_to_verify.inject({}) do |counts, table|
      counts.merge(table => @db[table].count)
    end
  end
end
