Sequel.migration do
  change do
    alter_table :v3_droplets do
      add_column :detected_start_command, String, null: true, size: 4096
    end
  end
end
