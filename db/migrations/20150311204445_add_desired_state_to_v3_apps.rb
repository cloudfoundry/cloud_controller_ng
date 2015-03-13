Sequel.migration do
  change do
    alter_table :apps_v3 do
      add_column :desired_state, String, default: 'STOPPED'
    end
  end
end
