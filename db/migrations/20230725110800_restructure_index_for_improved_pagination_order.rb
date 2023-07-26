Sequel.migration do
  up do
    #####################
    #### CREATED_AT #####
    #####################
    drop_index :organizations, nil, name: :organizations_created_at_index
    add_index :organizations, [:created_at, :guid], name: :organizations_created_at_guid_index

    drop_index :revisions, nil, name: :revisions_created_at_index
    add_index :revisions, [:created_at, :guid], name: :revisions_created_at_guid_index

    drop_index :services, nil, name: :services_created_at_index
    add_index :services, [:created_at, :guid], name: :services_created_at_guid_index

    drop_index :packages, nil, name: :packages_created_at_index
    add_index :packages, [:created_at, :guid], name: :packages_created_at_guid_index

    drop_index :routes, nil, name: :routes_created_at_index
    add_index :routes, [:created_at, :guid], name: :routes_created_at_guid_index

    drop_index :service_instances, nil, name: :si_created_at_index
    add_index :service_instances, [:created_at, :guid], name: :service_instances_created_at_guid_index

    drop_index :app_events, nil, name: :app_events_created_at_index
    add_index :app_events, [:created_at, :guid], name: :app_events_created_at_guid_index

    drop_index :apps, nil, name: :apps_v3_created_at_index
    add_index :apps, [:created_at, :guid], name: :apps_created_at_guid_index

    drop_index :service_usage_events, nil, name: :created_at_index
    add_index :service_usage_events, [:created_at, :guid], name: :service_usage_events_created_at_guid_index

    drop_index :sidecars, nil, name: :sidecars_created_at_index
    add_index :sidecars, [:created_at, :guid], name: :sidecars_created_at_guid_index

    drop_index :deployments, nil, name: :deployments_created_at_index
    add_index :deployments, [:created_at, :guid], name: :deployments_created_at_guid_index

    drop_index :security_groups, nil, name: :sg_created_at_index
    add_index :security_groups, [:created_at, :guid], name: :security_groups_created_at_guid_index

    drop_index :delayed_jobs, nil, name: :dj_created_at_index
    add_index :delayed_jobs, [:created_at, :guid], name: :delayed_jobs_created_at_guid_index

    drop_index :builds, nil, name: :builds_created_at_index
    add_index :builds, [:created_at, :guid], name: :builds_created_at_guid_index

    drop_index :quota_definitions, nil, name: :qd_created_at_index
    add_index :quota_definitions, [:created_at, :guid], name: :quota_definitions_created_at_guid_index

    drop_index :tasks, nil, name: :tasks_created_at_index
    add_index :tasks, [:created_at, :guid], name: :tasks_created_at_guid_index

    drop_index :droplets, nil, name: :droplets_created_at_index
    add_index :droplets, [:created_at, :guid], name: :droplets_created_at_guid_index

    drop_index :users, nil, name: :users_created_at_index
    add_index :users, [:created_at, :guid], name: :users_created_at_guid_index

    drop_index :space_quota_definitions, nil, name: :sqd_created_at_index
    add_index :space_quota_definitions, [:created_at, :guid], name: :space_quota_definitions_created_at_guid_index

    drop_index :isolation_segments, nil, name: :isolation_segments_created_at_index
    add_index :isolation_segments, [:created_at, :guid], name: :isolation_segments_created_at_guid_index

    drop_index :service_brokers, nil, name: :sbrokers_created_at_index
    add_index :service_brokers, [:created_at, :guid], name: :service_brokers_created_at_guid_index

    drop_index :processes, nil, name: :apps_created_at_index
    add_index :processes, [:created_at, :guid], name: :processes_created_at_guid_index

    drop_index :service_keys, nil, name: :sk_created_at_index
    add_index :service_keys, [:created_at, :guid], name: :service_keys_created_at_guid_index

    drop_index :service_plans, nil, name: :service_plans_created_at_index
    add_index :service_plans, [:created_at, :guid], name: :service_plans_created_at_guid_index

    drop_index :stacks, nil, name: :stacks_created_at_index
    add_index :stacks, [:created_at, :guid], name: :stacks_created_at_guid_index

    drop_index :route_bindings, nil, name: :route_bindings_created_at_index
    add_index :route_bindings, [:created_at, :guid], name: :route_bindings_created_at_guid_index

    drop_index :app_usage_events, nil, name: :usage_events_created_at_index
    add_index :app_usage_events, [:created_at, :guid], name: :app_usage_events_created_at_guid_index

    drop_index :jobs, nil, name: :jobs_created_at_index
    add_index :jobs, [:created_at, :guid], name: :jobs_created_at_guid_index

    drop_index :events, nil, name: :events_created_at_index
    add_index :events, [:created_at, :guid], name: :events_created_at_guid_index

    drop_index :service_bindings, nil, name: :sb_created_at_index
    add_index :service_bindings, [:created_at, :guid], name: :service_bindings_created_at_guid_index

    drop_index :domains, nil, name: :domains_created_at_index
    add_index :domains, [:created_at, :guid], name: :domains_created_at_guid_index

    drop_index :buildpacks, nil, name: :buildpacks_created_at_index
    add_index :buildpacks, [:created_at, :guid], name: :buildpacks_created_at_guid_index

    drop_index :spaces, nil, name: :spaces_created_at_index
    add_index :spaces, [:created_at, :guid], name: :spaces_created_at_guid_index

    #####################
    #### UPDATED_AT #####
    #####################

    drop_index :organizations, nil, name: :organizations_updated_at_index
    add_index :organizations, [:updated_at, :guid], name: :organizations_updated_at_guid_index

    drop_index :revisions, nil, name: :revisions_updated_at_index
    add_index :revisions, [:updated_at, :guid], name: :revisions_updated_at_guid_index

    drop_index :services, nil, name: :services_updated_at_index
    add_index :services, [:updated_at, :guid], name: :services_updated_at_guid_index

    drop_index :packages, nil, name: :packages_updated_at_index
    add_index :packages, [:updated_at, :guid], name: :packages_updated_at_guid_index

    drop_index :routes, nil, name: :routes_updated_at_index
    add_index :routes, [:updated_at, :guid], name: :routes_updated_at_guid_index

    drop_index :service_instances, nil, name: :si_updated_at_index
    add_index :service_instances, [:updated_at, :guid], name: :service_instances_updated_at_guid_index

    drop_index :app_events, nil, name: :app_events_updated_at_index
    add_index :app_events, [:updated_at, :guid], name: :app_events_updated_at_guid_index

    drop_index :apps, nil, name: :apps_v3_updated_at_index
    add_index :apps, [:updated_at, :guid], name: :apps_updated_at_guid_index

    drop_index :sidecars, nil, name: :sidecars_updated_at_index
    add_index :sidecars, [:updated_at, :guid], name: :sidecars_updated_at_guid_index

    drop_index :deployments, nil, name: :deployments_updated_at_index
    add_index :deployments, [:updated_at, :guid], name: :deployments_updated_at_guid_index

    drop_index :security_groups, nil, name: :sg_updated_at_index
    add_index :security_groups, [:updated_at, :guid], name: :security_groups_updated_at_guid_index

    drop_index :delayed_jobs, nil, name: :dj_updated_at_index
    add_index :delayed_jobs, [:updated_at, :guid], name: :delayed_jobs_updated_at_guid_index

    drop_index :builds, nil, name: :builds_updated_at_index
    add_index :builds, [:updated_at, :guid], name: :builds_updated_at_guid_index

    drop_index :quota_definitions, nil, name: :qd_updated_at_index
    add_index :quota_definitions, [:updated_at, :guid], name: :quota_definitions_updated_at_guid_index

    drop_index :tasks, nil, name: :tasks_updated_at_index
    add_index :tasks, [:updated_at, :guid], name: :tasks_updated_at_guid_index

    drop_index :droplets, nil, name: :droplets_updated_at_index
    add_index :droplets, [:updated_at, :guid], name: :droplets_updated_at_guid_index

    drop_index :users, nil, name: :users_updated_at_index
    add_index :users, [:updated_at, :guid], name: :users_updated_at_guid_index

    drop_index :space_quota_definitions, nil, name: :sqd_updated_at_index
    add_index :space_quota_definitions, [:updated_at, :guid], name: :space_quota_definitions_updated_at_guid_index

    drop_index :isolation_segments, nil, name: :isolation_segments_updated_at_index
    add_index :isolation_segments, [:updated_at, :guid], name: :isolation_segments_updated_at_guid_index

    drop_index :service_brokers, nil, name: :sbrokers_updated_at_index
    add_index :service_brokers, [:updated_at, :guid], name: :service_brokers_updated_at_guid_index

    drop_index :processes, nil, name: :apps_updated_at_index
    add_index :processes, [:updated_at, :guid], name: :processes_updated_at_guid_index

    drop_index :service_keys, nil, name: :sk_updated_at_index
    add_index :service_keys, [:updated_at, :guid], name: :service_keys_updated_at_guid_index

    drop_index :service_plans, nil, name: :service_plans_updated_at_index
    add_index :service_plans, [:updated_at, :guid], name: :service_plans_updated_at_guid_index

    drop_index :stacks, nil, name: :stacks_updated_at_index
    add_index :stacks, [:updated_at, :guid], name: :stacks_updated_at_guid_index

    drop_index :route_bindings, nil, name: :route_bindings_updated_at_index
    add_index :route_bindings, [:updated_at, :guid], name: :route_bindings_updated_at_guid_index

    drop_index :jobs, nil, name: :jobs_updated_at_index
    add_index :jobs, [:updated_at, :guid], name: :jobs_updated_at_guid_index

    drop_index :events, nil, name: :events_updated_at_index
    add_index :events, [:updated_at, :guid], name: :events_updated_at_guid_index

    drop_index :service_bindings, nil, name: :sb_updated_at_index
    add_index :service_bindings, [:updated_at, :guid], name: :service_bindings_updated_at_guid_index

    drop_index :domains, nil, name: :domains_updated_at_index
    add_index :domains, [:updated_at, :guid], name: :domains_updated_at_guid_index

    drop_index :buildpacks, nil, name: :buildpacks_updated_at_index
    add_index :buildpacks, [:updated_at, :guid], name: :buildpacks_updated_at_guid_index

    drop_index :spaces, nil, name: :spaces_updated_at_index
    add_index :spaces, [:updated_at, :guid], name: :spaces_updated_at_guid_index

    ##############
    #### NAME ####
    ##############

    add_index :organizations, [:name, :guid], name: :organizations_name_guid_index

    drop_index :services, nil, name: :services_label_index
    add_index :services, [:label, :guid], name: :services_label_guid_index

    drop_index :service_instances, nil, name: :service_instances_name_index
    add_index :service_instances, [:name, :guid], name: :service_instances_name_guid_index

    add_index :apps, [:name, :guid], name: :apps_name_guid_index

    add_index :isolation_segments, [:name, :guid], name: :isolation_segments_name_guid_index

    add_index :service_brokers, [:name, :guid], name: :service_brokers_name_guid_index

    add_index :service_keys, [:name, :guid], name: :service_keys_name_guid_index

    add_index :service_plans, [:name, :guid], name: :service_plans_name_guid_index

    add_index :stacks, [:name, :guid], name: :stacks_name_guid_index

    add_index :service_bindings, [:name, :guid], name: :service_bindings_name_guid_index

    add_index :spaces, [:name, :guid], name: :spaces_name_guid_index

    #######################
    #### DESIRED_STATE ####
    #######################
    add_index :apps, [:desired_state, :guid], name: :apps_desired_state_guid_index

    ##################
    #### POSITION ####
    ##################
    add_index :buildpacks, [:position, :guid], name: :buildpacks_position_guid_index
  end

  down do
    ####################
    #### CREATED_AT ####
    ####################
    drop_index :organizations, nil, name: :organizations_created_at_guid_index
    add_index :organizations, [:created_at], name: :organizations_created_at_index

    drop_index :revisions, nil, name: :revisions_created_at_guid_index
    add_index :revisions, [:created_at], name: :revisions_created_at_index

    drop_index :services, nil, name: :services_created_at_guid_index
    add_index :services, [:created_at], name: :services_created_at_index

    drop_index :packages, nil, name: :packages_created_at_guid_index
    add_index :packages, [:created_at], name: :packages_created_at_index

    drop_index :routes, nil, name: :routes_created_at_guid_index
    add_index :routes, [:created_at], name: :routes_created_at_index

    drop_index :service_instances, nil, name: :service_instances_created_at_guid_index
    add_index :service_instances, [:created_at], name: :si_created_at_index

    drop_index :app_events, nil, name: :app_events_created_at_guid_index
    add_index :app_events, [:created_at], name: :app_events_created_at_index

    drop_index :apps, nil, name: :apps_created_at_guid_index
    add_index :apps, [:created_at], name: :apps_v3_created_at_index

    drop_index :service_usage_events, nil, name: :service_usage_events_created_at_guid_index
    add_index :service_usage_events, [:created_at], name: :created_at_index

    drop_index :sidecars, nil, name: :sidecars_created_at_guid_index
    add_index :sidecars, [:created_at], name: :sidecars_created_at_index

    drop_index :deployments, nil, name: :deployments_created_at_guid_index
    add_index :deployments, [:created_at], name: :deployments_created_at_index

    drop_index :security_groups, nil, name: :security_groups_created_at_guid_index
    add_index :security_groups, [:created_at], name: :sg_created_at_index

    drop_index :delayed_jobs, nil, name: :delayed_jobs_created_at_guid_index
    add_index :delayed_jobs, [:created_at], name: :dj_created_at_index

    drop_index :builds, nil, name: :builds_created_at_guid_index
    add_index :builds, [:created_at], name: :builds_created_at_index

    drop_index :quota_definitions, nil, name: :quota_definitions_created_at_guid_index
    add_index :quota_definitions, [:created_at], name: :qd_created_at_index

    drop_index :tasks, nil, name: :tasks_created_at_guid_index
    add_index :tasks, [:created_at], name: :tasks_created_at_index

    drop_index :droplets, nil, name: :droplets_created_at_guid_index
    add_index :droplets, [:created_at], name: :droplets_created_at_index

    drop_index :users, nil, name: :users_created_at_guid_index
    add_index :users, [:created_at], name: :users_created_at_index

    drop_index :space_quota_definitions, nil, name: :space_quota_definitions_created_at_guid_index
    add_index :space_quota_definitions, [:created_at], name: :sqd_created_at_index

    drop_index :isolation_segments, nil, name: :isolation_segments_created_at_guid_index
    add_index :isolation_segments, [:created_at], name: :isolation_segments_created_at_index

    drop_index :service_brokers, nil, name: :service_brokers_created_at_guid_index
    add_index :service_brokers, [:created_at], name: :sbrokers_created_at_index

    drop_index :processes, nil, name: :processes_created_at_guid_index
    add_index :processes, [:created_at], name: :apps_created_at_index

    drop_index :service_keys, nil, name: :service_keys_created_at_guid_index
    add_index :service_keys, [:created_at], name: :sk_created_at_index

    drop_index :service_plans, nil, name: :service_plans_created_at_guid_index
    add_index :service_plans, [:created_at], name: :service_plans_created_at_index

    drop_index :stacks, nil, name: :stacks_created_at_guid_index
    add_index :stacks, [:created_at], name: :stacks_created_at_index

    drop_index :route_bindings, nil, name: :route_bindings_created_at_guid_index
    add_index :route_bindings, [:created_at], name: :route_bindings_created_at_index

    drop_index :app_usage_events, nil, name: :app_usage_events_created_at_guid_index
    add_index :app_usage_events, [:created_at], name: :usage_events_created_at_index

    drop_index :jobs, nil, name: :jobs_created_at_guid_index
    add_index :jobs, [:created_at], name: :jobs_created_at_index

    drop_index :events, nil, name: :events_created_at_guid_index
    add_index :events, [:created_at], name: :events_created_at_index

    drop_index :service_bindings, nil, name: :service_bindings_created_at_guid_index
    add_index :service_bindings, [:created_at], name: :sb_created_at_index

    drop_index :domains, nil, name: :domains_created_at_guid_index
    add_index :domains, [:created_at], name: :domains_created_at_index

    drop_index :buildpacks, nil, name: :buildpacks_created_at_guid_index
    add_index :buildpacks, [:created_at], name: :buildpacks_created_at_index

    drop_index :spaces, nil, name: :spaces_created_at_guid_index
    add_index :spaces, [:created_at], name: :spaces_created_at_index

    ####################
    #### UPDATED_AT ####
    ####################

    drop_index :organizations, nil, name: :organizations_updated_at_guid_index
    add_index :organizations, [:updated_at], name: :organizations_updated_at_index

    drop_index :revisions, nil, name: :revisions_updated_at_guid_index
    add_index :revisions, [:updated_at], name: :revisions_updated_at_index

    drop_index :services, nil, name: :services_updated_at_guid_index
    add_index :services, [:updated_at], name: :services_updated_at_index

    drop_index :packages, nil, name: :packages_updated_at_guid_index
    add_index :packages, [:updated_at], name: :packages_updated_at_index

    drop_index :routes, nil, name: :routes_updated_at_guid_index
    add_index :routes, [:updated_at], name: :routes_updated_at_index

    drop_index :service_instances, nil, name: :service_instances_updated_at_guid_index
    add_index :service_instances, [:updated_at], name: :si_updated_at_index

    drop_index :app_events, nil, name: :app_events_updated_at_guid_index
    add_index :app_events, [:updated_at], name: :app_events_updated_at_index

    drop_index :apps, nil, name: :apps_updated_at_guid_index
    add_index :apps, [:updated_at], name: :apps_v3_updated_at_index

    drop_index :sidecars, nil, name: :sidecars_updated_at_guid_index
    add_index :sidecars, [:updated_at], name: :sidecars_updated_at_index

    drop_index :deployments, nil, name: :deployments_updated_at_guid_index
    add_index :deployments, [:updated_at], name: :deployments_updated_at_index

    drop_index :security_groups, nil, name: :security_groups_updated_at_guid_index
    add_index :security_groups, [:updated_at], name: :sg_updated_at_index

    drop_index :delayed_jobs, nil, name: :delayed_jobs_updated_at_guid_index
    add_index :delayed_jobs, [:updated_at], name: :dj_updated_at_index

    drop_index :builds, nil, name: :builds_updated_at_guid_index
    add_index :builds, [:updated_at], name: :builds_updated_at_index

    drop_index :quota_definitions, nil, name: :quota_definitions_updated_at_guid_index
    add_index :quota_definitions, [:updated_at], name: :qd_updated_at_index

    drop_index :tasks, nil, name: :tasks_updated_at_guid_index
    add_index :tasks, [:updated_at], name: :tasks_updated_at_index

    drop_index :droplets, nil, name: :droplets_updated_at_guid_index
    add_index :droplets, [:updated_at], name: :droplets_updated_at_index

    drop_index :users, nil, name: :users_updated_at_guid_index
    add_index :users, [:updated_at], name: :users_updated_at_index

    drop_index :space_quota_definitions, nil, name: :space_quota_definitions_updated_at_guid_index
    add_index :space_quota_definitions, [:updated_at], name: :sqd_updated_at_index

    drop_index :isolation_segments, nil, name: :isolation_segments_updated_at_guid_index
    add_index :isolation_segments, [:updated_at], name: :isolation_segments_updated_at_index

    drop_index :service_brokers, nil, name: :service_brokers_updated_at_guid_index
    add_index :service_brokers, [:updated_at], name: :sbrokers_updated_at_index

    drop_index :processes, nil, name: :processes_updated_at_guid_index
    add_index :processes, [:updated_at], name: :apps_updated_at_index

    drop_index :service_keys, nil, name: :service_keys_updated_at_guid_index
    add_index :service_keys, [:updated_at], name: :sk_updated_at_index

    drop_index :service_plans, nil, name: :service_plans_updated_at_guid_index
    add_index :service_plans, [:updated_at], name: :service_plans_updated_at_index

    drop_index :stacks, nil, name: :stacks_updated_at_guid_index
    add_index :stacks, [:updated_at], name: :stacks_updated_at_index

    drop_index :route_bindings, nil, name: :route_bindings_updated_at_guid_index
    add_index :route_bindings, [:updated_at], name: :route_bindings_updated_at_index

    drop_index :jobs, nil, name: :jobs_updated_at_guid_index
    add_index :jobs, [:updated_at], name: :jobs_updated_at_index

    drop_index :events, nil, name: :events_updated_at_guid_index
    add_index :events, [:updated_at], name: :events_updated_at_index

    drop_index :service_bindings, nil, name: :service_bindings_updated_at_guid_index
    add_index :service_bindings, [:updated_at], name: :sb_updated_at_index

    drop_index :domains, nil, name: :domains_updated_at_guid_index
    add_index :domains, [:updated_at], name: :domains_updated_at_index

    drop_index :buildpacks, nil, name: :buildpacks_updated_at_guid_index
    add_index :buildpacks, [:updated_at], name: :buildpacks_updated_at_index

    drop_index :spaces, nil, name: :spaces_updated_at_guid_index
    add_index :spaces, [:updated_at], name: :spaces_updated_at_index

    #####################
    #### Name #####
    #####################

    drop_index :organizations, nil, name: :organizations_name_guid_index

    drop_index :services, nil, name: :services_label_guid_index
    add_index :services, [:label], name: :services_label_index

    drop_index :service_instances, nil, name: :service_instances_name_guid_index
    add_index :service_instances, [:name], name: :service_instances_name_index

    drop_index :apps, nil, name: :apps_name_guid_index

    drop_index :isolation_segments, nil, name: :isolation_segments_name_guid_index

    drop_index :service_brokers, nil, name: :service_brokers_name_guid_index

    drop_index :service_keys, nil, name: :service_keys_name_guid_index

    drop_index :service_plans, nil, name: :service_plans_name_guid_index

    drop_index :stacks, nil, name: :stacks_name_guid_index

    drop_index :service_bindings, nil, name: :service_bindings_name_guid_index

    drop_index :spaces, nil, name: :spaces_name_guid_index

    #######################
    #### DESIRED_STATE ####
    #######################
    drop_index :apps, nil, name: :apps_desired_state_guid_index

    ##################
    #### POSITION ####
    ##################
    drop_index :buildpacks, nil, name: :buildpacks_position_guid_index
  end
end
