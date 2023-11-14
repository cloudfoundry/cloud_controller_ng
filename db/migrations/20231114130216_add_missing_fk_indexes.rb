def migration_name(table, columns)
  "#{table}_#{columns.join('_')}_index"
end

Sequel.migration do
  foreign_key_indexes = [
    { table: :organizations, columns: %i[quota_definition_id] },
    { table: :organizations, columns: %i[guid default_isolation_segment_guid] },
    { table: :domains, columns: %i[owning_organization_id] },
    { table: :spaces, columns: %i[isolation_segment_guid] },
    { table: :routes, columns: %i[domain_id] },
    { table: :routes, columns: %i[space_id] },
    { table: :users, columns: %i[default_space_id] },
    { table: :organizations_users, columns: %i[user_id] },
    { table: :organizations_managers, columns: %i[user_id] },
    { table: :organizations_billing_managers, columns: %i[user_id] },
    { table: :organizations_auditors, columns: %i[user_id] },
    { table: :spaces_developers, columns: %i[user_id] },
    { table: :spaces_managers, columns: %i[user_id] },
    { table: :spaces_auditors, columns: %i[user_id] },
    { table: :organizations_private_domains, columns: %i[private_domain_id] },
    { table: :route_bindings, columns: %i[route_id] },
    { table: :route_bindings, columns: %i[service_instance_id] },
    { table: :organizations_isolation_segments, columns: %i[isolation_segment_guid] },
    { table: :staging_security_groups_spaces, columns: %i[staging_space_id] },
    { table: :service_instance_shares, columns: %i[target_space_guid] },
    { table: :job_warnings, columns: %i[fk_jobs_id] },
    { table: :service_broker_update_requests, columns: %i[fk_service_brokers_id] },
    { table: :kpack_lifecycle_data, columns: %i[app_guid] },
    { table: :spaces_supporters, columns: %i[user_id] },
    { table: :route_shares, columns: %i[target_space_guid] }
  ]

  no_transaction # Disable automatic transactions

  up do
    if database_type == :postgres
      foreign_key_indexes.each do |index|
        add_index index[:table], index[:columns], name: migration_name(index[:table], index[:columns]), concurrently: true, if_not_exists: true
      end
    end
  end

  down do
    if database_type == :postgres
      foreign_key_indexes.each do |index|
        drop_index index[:table], nil, name: migration_name(index[:table], index[:columns]), concurrently: true, if_exists: true
      end
    end
  end
end
