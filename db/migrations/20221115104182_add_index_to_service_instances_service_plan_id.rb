Sequel.migration do
  change do
    alter_table :service_instances do
      add_index :service_plan_id, name: :si_service_plan_id_index
    end
  end
end
