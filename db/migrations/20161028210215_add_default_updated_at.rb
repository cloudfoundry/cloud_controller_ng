Sequel.migration do
  change do
    tables_to_migrate = [
      :apps,
      :buildpack_lifecycle_data,
      :buildpacks,
      :delayed_jobs,
      :domains,
      :droplets,
      :env_groups,
      :feature_flags,
      :isolation_segments,
      :organizations,
      :packages,
      :processes,
      :quota_definitions,
      :route_bindings,
      :route_mappings,
      :routes,
      :security_groups,
      :service_auth_tokens,
      :service_bindings,
      :service_brokers,
      :service_dashboard_clients,
      :service_instance_operations,
      :service_instances,
      :service_keys,
      :service_plans,
      :service_plan_visibilities,
      :services,
      :space_quota_definitions,
      :spaces,
      :stacks,
      :tasks,
      :users
    ]

    tables_to_migrate.each do |table|
      self[table].where(:updated_at => nil).update(:updated_at=>:created_at)
    end
  end
end
