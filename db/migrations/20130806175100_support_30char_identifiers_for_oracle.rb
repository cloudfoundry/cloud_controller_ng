# Copyright (c) 2009-2012 VMware, Inc.
# rubocop:disable Metrics/LineLength
# rubocop:disable Lint/ShadowingOuterLocalVariable

def rename_foreign_key_internal(db, alter_table, table, current_name, new_name, &block)
  processed = false
  db.foreign_key_list(table).each do |fk|
    if fk[:name] && fk[:name] == current_name
      alter_table.drop_constraint current_name, type: :foreign_key
      block.call(db, alter_table) unless block.nil?
      alter_table.add_foreign_key fk[:columns], fk[:table], name: new_name
      processed = true
    end
  end
  # Since Sqlite doesn't return fk names let's just not rename them but still rename the nested index.
  if !processed
    block.call(db, alter_table) unless block.nil?
  end
end

def rename_foreign_key(table, current_name, new_name, &block)
  db = self
  alter_table table do
    rename_foreign_key_internal(db, self, table, current_name, new_name, &block)
  end
end

def rename_index_internal(db, alter_table, table, columns, opts={})
  columns = [columns] unless columns.is_a?(Array)
  db.indexes(table).each do | name, index |
    if (index[:columns] - columns).empty? &&
        (columns - index[:columns]).empty? &&
        name != opts[:name]
      alter_table.drop_index columns
      alter_table.add_index columns, opts
      break
    end
  end
end

def rename_index(table, columns, opts={})
  db = self
  alter_table table do
    rename_index_internal(db, self, table, columns, opts)
  end
end

def rename_common_indexes(table, table_key)
  rename_index(table, :created_at, name: "#{table_key}_created_at_index".to_sym)
  rename_index(table, :updated_at, name: "#{table_key}_updated_at_index".to_sym)
  rename_index(table, :guid, unique: true, name: "#{table_key}_guid_index".to_sym)
end

def rename_permission_table(name, name_short, permission)
  name = name.to_s
  join_table = "#{name.pluralize}_#{permission}".to_sym
  join_table_short = "#{name_short}_#{permission}".to_sym
  id_attr = "#{name}_id".to_sym
  idx_name = "#{name_short}_#{permission}_idx".to_sym
  fk_name = "#{join_table}_#{name}_fk".to_sym
  fk_user = "#{join_table}_user_fk".to_sym
  fk_name_short = "#{join_table_short}_#{name_short}_fk".to_sym
  fk_user_short = "#{join_table_short}_user_fk".to_sym

  rename_foreign_key(join_table, fk_name, fk_name_short) do | db, alter_table |
    rename_foreign_key_internal(db, alter_table, join_table, fk_user, fk_user_short) do | db, alter_table |
      rename_index_internal(db, alter_table, join_table, [id_attr, :user_id], unique: true, name: idx_name)
    end
  end
end

Sequel.migration do
  up do
    rename_foreign_key(:organizations, :fk_organizations_quota_definition_id, :fk_org_quota_definition_id)
    rename_foreign_key(:domains, :fk_domains_owning_organization_id, :fk_domains_owning_org_id)
    rename_foreign_key(:domains_organizations, :fk_domains_organizations_organization_id, :fk_domains_orgs_org_id)
    rename_foreign_key(:service_instances, :service_instances_service_plan_id, :svc_instances_service_plan_id)

    # Where indexes and fk cross mysql requires that the fk be dropped before the index is dropped
    rename_foreign_key(:service_plans, :fk_service_plans_service_id, :fk_service_plans_service_id) do | db, alter_table |
      rename_index_internal(db, alter_table, :service_plans, [:service_id, :name], unique: true, name: :svc_plan_svc_id_name_index)
    end
    rename_foreign_key(:spaces, :fk_spaces_organization_id, :fk_spaces_organization_id) do | db, alter_table |
      rename_index_internal(db, alter_table, :spaces, [:organization_id, :name], unique: true, name: :spaces_org_id_name_index)
    end
    rename_foreign_key(:domains_organizations, :fk_domains_organizations_domain_id, :fk_domains_orgs_domain_id) do | db, alter_table |
      rename_index_internal(db, alter_table, :domains_organizations, [:domain_id, :organization_id], unique: true, name: :do_domain_id_org_id_index)
    end
    rename_foreign_key(:domains_spaces, :fk_domains_spaces_space_id, :fk_domains_spaces_space_id) do | db, alter_table |
      rename_foreign_key_internal(db, alter_table, :domains_spaces, :fk_domains_spaces_domain_id, :fk_domains_spaces_domain_id) do | db, alter_table |
        rename_index_internal(db, alter_table, :domains_spaces, [:space_id, :domain_id], unique: true, name: :ds_space_id_domain_id_index)
      end
    end
    rename_foreign_key(:service_instances, :service_instances_space_id, :service_instances_space_id) do | db, alter_table |
      rename_index_internal(db, alter_table, :service_instances, [:space_id, :name], unique: true, name: :si_space_id_name_index)
    end

    rename_foreign_key(:apps_routes, :fk_apps_routes_app_id, :fk_apps_routes_app_id) do | db, alter_table |
      rename_foreign_key_internal(db, alter_table, :apps_routes, :fk_apps_routes_route_id, :fk_apps_routes_route_id) do | db, alter_table |
        rename_index_internal(db, alter_table, :apps_routes, [:app_id, :route_id], unique: true, name: :ar_app_id_route_id_index)
      end
    end

    rename_foreign_key(:service_bindings, :fk_service_bindings_service_instance_id, :fk_sb_service_instance_id) do | db, alter_table |
      rename_foreign_key_internal(db, alter_table, :service_bindings, :fk_service_bindings_app_id, :fk_service_bindings_app_id) do | db, alter_table |
        rename_index_internal(db, alter_table, :service_bindings, [:app_id, :service_instance_id], unique: true, name: :sb_app_id_srv_inst_id_index)
      end
    end

    rename_index(:billing_events, :timestamp, name: :be_event_timestamp_index)
    rename_common_indexes(:billing_events, :be)
    rename_index(:quota_definitions, :name, unique: true, name: :qd_name_index)
    rename_common_indexes(:quota_definitions, :qd)
    rename_index(:service_auth_tokens, [:label, :provider], unique: true, name: :sat_label_provider_index)
    rename_common_indexes(:service_auth_tokens, :sat)
    rename_index(:services, [:label, :provider], unique: true, name: :services_label_provider_index)
    rename_index(:organizations, :name, unique: true, name: :organizations_name_index)
    rename_index(:routes, [:host, :domain_id], unique: true, name: :routes_host_domain_id_index)
    rename_common_indexes(:service_instances, :si)
    rename_index(:service_instances, :name, name: :service_instances_name_index)
    rename_common_indexes(:service_bindings, :sb)

    rename_foreign_key(:apps, :fk_apps_space_id, :fk_apps_space_id) do | db, alter_table |
      rename_index_internal(db, alter_table, :apps, [:space_id, :name, :not_deleted], unique: true, name: :apps_space_id_name_nd_idx)
    end

    rename_index(:service_instances, :gateway_name, name: :si_gateway_name_index)

    rename_foreign_key(:service_plan_visibilities, :fk_service_plan_visibilities_organization_id, :fk_spv_organization_id) do | db, alter_table |
      rename_foreign_key_internal(db, alter_table, :service_plan_visibilities, :fk_service_plan_visibilities_service_plan_id, :fk_spv_service_plan_id) do | db, alter_table |
        rename_index_internal(db, alter_table, :service_plan_visibilities, [:organization_id, :service_plan_id], unique: true, name: :spv_org_id_sp_id_index)
      end
    end

    rename_common_indexes(:service_plan_visibilities, :spv)
    rename_common_indexes(:service_brokers, :sbrokers)
    rename_index(:service_brokers, :broker_url, unique: true, name: :sb_broker_url_index)

    [:users, :managers, :billing_managers, :auditors].each do |perm|
      rename_permission_table(:organization, :org, perm)
    end

    [:developers, :managers, :auditors].each do |perm|
      rename_permission_table(:space, :space, perm)
    end
  end

  down do
    raise Sequel::Error.new("This migration cannot be reversed since we don't know if 'timestamp' and the fks were renamed originally.")
  end
end
# rubocop:enable Metrics/LineLength
# rubocop:enable Lint/ShadowingOuterLocalVariable
