Sequel.migration do
  annotaion_tables_to_migrate = {
    app_annotations: 'app_ann',
    build_annotations: 'build_ann',
    buildpack_annotations: 'buildp_ann',
    deployment_annotations: 'depl_ann',
    domain_annotations: 'dom_ann',
    droplet_annotations: 'drop_ann',
    isolation_segment_annotations: 'iso_ann',
    organization_annotations: 'org_ann',
    package_annotations: 'pack_ann',
    process_annotations: 'proc_ann',
    revision_annotations: 'rev_ann',
    route_annotations: 'rt_ann',
    route_binding_annotations: 'rt_bind_ann',
    service_binding_annotations: 'sv_bind_ann',
    service_broker_annotations: 'svbr_ann',
    service_broker_update_request_annotations: 'svcbr_upd_req_ann',
    service_instance_annotations: 'sv_inst_ann',
    service_key_annotations: 'sv_key_ann',
    service_offering_annotations: 'sv_off_ann',
    service_plan_annotations: 'sv_plan_ann',
    space_annotations: 'space_ann',
    stack_annotations: 'stack_ann',
    task_annotations: 'task_ann',
    user_annotations: 'user_ann',
  }
  label_tables_to_migrate = {
    app_labels: 'app_lab',
    build_labels:  'build_lab',
    buildpack_labels: 'buildp_lab',
    deployment_labels: 'depl_lab',
    domain_labels: 'dom_lab',
    droplet_labels: 'drop_lab',
    isolation_segment_labels: 'iso_lab',
    organization_labels: 'org_lab',
    package_labels: 'pack_lab',
    process_labels: 'proc_lab',
    revision_labels: 'rev_lab',
    route_binding_labels: 'rt_bind_lab',
    route_labels: 'rt_lab',
    service_binding_labels: 'sv_bind_lab',
    service_broker_labels: 'svbr_lab',
    service_broker_update_request_labels: 'svbr_upd_req_lab',
    service_instance_labels: 'sv_inst_lab',
    service_key_labels: 'sv_key_lab',
    service_offering_labels: 'sv_off_lab',
    service_plan_labels: 'sv_plan_lab',
    space_labels: 'space_lab',
    stack_labels: 'stack_lab',
    task_labels: 'task_lab',
    user_labels: 'user_lab'
  }

  up do
    label_tables_to_migrate.each do |table, table_short|
      alter_table table do
        add_column :resource_guid_key_prefix_key_name_hash, String, size: 70, default: '0', allow_null: false
      end
    end

    annotaion_tables_to_migrate.each do |table, table_short|
      alter_table table do
        add_column :resource_guid_key_prefix_key_hash, String, size: 70, default: '0', allow_null: false
      end
    end
  end


  down do
    label_tables_to_migrate.each do |table, table_short|
      alter_table table do
        drop_column :resource_guid_key_prefix_key_name_hash
      end
    end
    annotaion_tables_to_migrate.each do |table, table_short|
      alter_table table do
        drop_column :resource_guid_key_prefix_key_hash
      end
    end
  end
end
