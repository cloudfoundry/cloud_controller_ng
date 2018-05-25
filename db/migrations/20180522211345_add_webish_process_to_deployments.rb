Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :webish_process_guid, String, size: 255
    end
  end

  down do
    alter_table(:deployments) do
      drop_column :webish_process_guid
    end
  end
end
