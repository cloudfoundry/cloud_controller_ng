Sequel.migration do
  up do
    alter_table :apps do
      add_column :service_binding_k8s_enabled, :boolean, default: false, null: false
      add_column :file_based_vcap_services_enabled, :boolean, default: false, null: false
      add_constraint(name: :only_one_sb_feature_enabled) do
        Sequel.lit('NOT (service_binding_k8s_enabled AND file_based_vcap_services_enabled)')
      end
    end
  end

  down do
    alter_table :apps do
      drop_column :service_binding_k8s_enabled
      drop_column :file_based_vcap_services_enabled
      drop_constraint(name: :only_one_sb_feature_enabled)
    end
  end
end
