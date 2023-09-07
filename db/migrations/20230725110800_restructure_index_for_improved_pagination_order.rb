Sequel.migration do
  index_migration_data = [
    # CREATED AT
    {
      table: :organizations,
      old_index: :organizations_created_at_index,
      old_columns: [:created_at],
      new_index: :organizations_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :revisions,
      old_index: :revisions_created_at_index,
      old_columns: [:created_at],
      new_index: :revisions_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :services,
      old_index: :services_created_at_index,
      old_columns: [:created_at],
      new_index: :services_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :packages,
      old_index: :packages_created_at_index,
      old_columns: [:created_at],
      new_index: :packages_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :routes,
      old_index: :routes_created_at_index,
      old_columns: [:created_at],
      new_index: :routes_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_instances,
      old_index: :si_created_at_index,
      old_columns: [:created_at],
      new_index: :service_instances_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :app_events,
      old_index: :app_events_created_at_index,
      old_columns: [:created_at],
      new_index: :app_events_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :apps,
      old_index: :apps_v3_created_at_index,
      old_columns: [:created_at],
      new_index: :apps_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_usage_events,
      old_index: :created_at_index,
      old_columns: [:created_at],
      new_index: :service_usage_events_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :sidecars,
      old_index: :sidecars_created_at_index,
      old_columns: [:created_at],
      new_index: :sidecars_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :deployments,
      old_index: :deployments_created_at_index,
      old_columns: [:created_at],
      new_index: :deployments_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :security_groups,
      old_index: :sg_created_at_index,
      old_columns: [:created_at],
      new_index: :security_groups_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :delayed_jobs,
      old_index: :dj_created_at_index,
      old_columns: [:created_at],
      new_index: :delayed_jobs_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :builds,
      old_index: :builds_created_at_index,
      old_columns: [:created_at],
      new_index: :builds_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :quota_definitions,
      old_index: :qd_created_at_index,
      old_columns: [:created_at],
      new_index: :quota_definitions_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :tasks,
      old_index: :tasks_created_at_index,
      old_columns: [:created_at],
      new_index: :tasks_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :droplets,
      old_index: :droplets_created_at_index,
      old_columns: [:created_at],
      new_index: :droplets_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :users,
      old_index: :users_created_at_index,
      old_columns: [:created_at],
      new_index: :users_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :space_quota_definitions,
      old_index: :sqd_created_at_index,
      old_columns: [:created_at],
      new_index: :space_quota_definitions_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :isolation_segments,
      old_index: :isolation_segments_created_at_index,
      old_columns: [:created_at],
      new_index: :isolation_segments_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_brokers,
      old_index: :sbrokers_created_at_index,
      old_columns: [:created_at],
      new_index: :service_brokers_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :processes,
      old_index: :apps_created_at_index,
      old_columns: [:created_at],
      new_index: :processes_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_keys,
      old_index: :sk_created_at_index,
      old_columns: [:created_at],
      new_index: :service_keys_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_plans,
      old_index: :service_plans_created_at_index,
      old_columns: [:created_at],
      new_index: :service_plans_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :stacks,
      old_index: :stacks_created_at_index,
      old_columns: [:created_at],
      new_index: :stacks_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :route_bindings,
      old_index: :route_bindings_created_at_index,
      old_columns: [:created_at],
      new_index: :route_bindings_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :app_usage_events,
      old_index: :usage_events_created_at_index,
      old_columns: [:created_at],
      new_index: :app_usage_events_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :jobs,
      old_index: :jobs_created_at_index,
      old_columns: [:created_at],
      new_index: :jobs_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :events,
      old_index: :events_created_at_index,
      old_columns: [:created_at],
      new_index: :events_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :service_bindings,
      old_index: :sb_created_at_index,
      old_columns: [:created_at],
      new_index: :service_bindings_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :domains,
      old_index: :domains_created_at_index,
      old_columns: [:created_at],
      new_index: :domains_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :buildpacks,
      old_index: :buildpacks_created_at_index,
      old_columns: [:created_at],
      new_index: :buildpacks_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    {
      table: :spaces,
      old_index: :spaces_created_at_index,
      old_columns: [:created_at],
      new_index: :spaces_created_at_guid_index,
      new_columns: [:created_at, :guid]
    },
    # UPDATED AT
    {
      table: :organizations,
      old_index: :organizations_updated_at_index,
      old_columns: [:updated_at],
      new_index: :organizations_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :revisions,
      old_index: :revisions_updated_at_index,
      old_columns: [:updated_at],
      new_index: :revisions_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :services,
      old_index: :services_updated_at_index,
      old_columns: [:updated_at],
      new_index: :services_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :packages,
      old_index: :packages_updated_at_index,
      old_columns: [:updated_at],
      new_index: :packages_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :routes,
      old_index: :routes_updated_at_index,
      old_columns: [:updated_at],
      new_index: :routes_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :service_instances,
      old_index: :si_updated_at_index,
      old_columns: [:updated_at],
      new_index: :service_instances_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :app_events,
      old_index: :app_events_updated_at_index,
      old_columns: [:updated_at],
      new_index: :app_events_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :apps,
      old_index: :apps_v3_updated_at_index,
      old_columns: [:updated_at],
      new_index: :apps_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :sidecars,
      old_index: :sidecars_updated_at_index,
      old_columns: [:updated_at],
      new_index: :sidecars_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :deployments,
      old_index: :deployments_updated_at_index,
      old_columns: [:updated_at],
      new_index: :deployments_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :security_groups,
      old_index: :sg_updated_at_index,
      old_columns: [:updated_at],
      new_index: :security_groups_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :delayed_jobs,
      old_index: :dj_updated_at_index,
      old_columns: [:updated_at],
      new_index: :delayed_jobs_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :builds,
      old_index: :builds_updated_at_index,
      old_columns: [:updated_at],
      new_index: :builds_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :quota_definitions,
      old_index: :qd_updated_at_index,
      old_columns: [:updated_at],
      new_index: :quota_definitions_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :tasks,
      old_index: :tasks_updated_at_index,
      old_columns: [:updated_at],
      new_index: :tasks_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :droplets,
      old_index: :droplets_updated_at_index,
      old_columns: [:updated_at],
      new_index: :droplets_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :users,
      old_index: :users_updated_at_index,
      old_columns: [:updated_at],
      new_index: :users_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :space_quota_definitions,
      old_index: :sqd_updated_at_index,
      old_columns: [:updated_at],
      new_index: :space_quota_definitions_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :isolation_segments,
      old_index: :isolation_segments_updated_at_index,
      old_columns: [:updated_at],
      new_index: :isolation_segments_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :service_brokers,
      old_index: :sbrokers_updated_at_index,
      old_columns: [:updated_at],
      new_index: :service_brokers_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :processes,
      old_index: :apps_updated_at_index,
      old_columns: [:updated_at],
      new_index: :processes_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :service_keys,
      old_index: :sk_updated_at_index,
      old_columns: [:updated_at],
      new_index: :service_keys_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :service_plans,
      old_index: :service_plans_updated_at_index,
      old_columns: [:updated_at],
      new_index: :service_plans_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :stacks,
      old_index: :stacks_updated_at_index,
      old_columns: [:updated_at],
      new_index: :stacks_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :route_bindings,
      old_index: :route_bindings_updated_at_index,
      old_columns: [:updated_at],
      new_index: :route_bindings_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :jobs,
      old_index: :jobs_updated_at_index,
      old_columns: [:updated_at],
      new_index: :jobs_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :events,
      old_index: :events_updated_at_index,
      old_columns: [:updated_at],
      new_index: :events_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :service_bindings,
      old_index: :sb_updated_at_index,
      old_columns: [:updated_at],
      new_index: :service_bindings_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :domains,
      old_index: :domains_updated_at_index,
      old_columns: [:updated_at],
      new_index: :domains_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :buildpacks,
      old_index: :buildpacks_updated_at_index,
      old_columns: [:updated_at],
      new_index: :buildpacks_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    {
      table: :spaces,
      old_index: :spaces_updated_at_index,
      old_columns: [:updated_at],
      new_index: :spaces_updated_at_guid_index,
      new_columns: [:updated_at, :guid]
    },
    # LABEL
    {
      table: :services,
      old_index: :services_label_index,
      old_columns: [:label],
      new_index: :services_label_guid_index,
      new_columns: [:label, :guid]
    },
    # NAME
    {
      table: :organizations,
      old_index: nil,
      old_columns: nil,
      new_index: :organizations_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :service_instances,
      old_index: :service_instances_name_index,
      old_columns: [:name],
      new_index: :service_instances_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :apps,
      old_index: nil,
      old_columns: nil,
      new_index: :apps_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :isolation_segments,
      old_index: nil,
      old_columns: nil,
      new_index: :isolation_segments_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :service_brokers,
      old_index: nil,
      old_columns: nil,
      new_index: :service_brokers_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :service_keys,
      old_index: nil,
      old_columns: nil,
      new_index: :service_keys_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :service_plans,
      old_index: nil,
      old_columns: nil,
      new_index: :service_plans_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :stacks,
      old_index: nil,
      old_columns: nil,
      new_index: :stacks_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :service_bindings,
      old_index: nil,
      old_columns: nil,
      new_index: :service_bindings_name_guid_index,
      new_columns: [:name, :guid]
    },
    {
      table: :spaces,
      old_index: nil,
      old_columns: nil,
      new_index: :spaces_name_guid_index,
      new_columns: [:name, :guid]
    },
    # DESIRED_STATE
    {
      table: :apps,
      old_index: nil,
      old_columns: nil,
      new_index: :apps_desired_state_guid_index,
      new_columns: [:desired_state, :guid]
    },
    # POSITION
    {
      table: :buildpacks,
      old_index: nil,
      old_columns: nil,
      new_index: :buildpacks_position_guid_index,
      new_columns: [:position, :guid]
    },
  ]

  no_transaction
  up do
    index_migration_data.each do |index_migration|
      transaction do
        if index_migration[:old_index].present? && index_migration[:old_columns].present?
          drop_index index_migration[:table], nil, name: index_migration[:old_index], if_exists: true
        end
        if self.indexes(index_migration[:table])[index_migration[:new_index]].nil?
          add_index index_migration[:table], index_migration[:new_columns], name: index_migration[:new_index]
        end
      end
    end
  end

  down do
    index_migration_data.each do |index_migration|
      transaction do
        drop_index index_migration[:table], nil, name: index_migration[:new_index], if_exists: true
        if index_migration[:old_index].present? && index_migration[:old_columns].present? && self.indexes(index_migration[:table])[index_migration[:old_index]].nil?
          add_index index_migration[:table], index_migration[:old_columns], name: index_migration[:old_index]
        end
      end
    end
  end
end
