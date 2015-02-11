Sequel.migration do
  change do
    alter_table :v3_droplets do
      add_column :failure_reason, String, null: true, size: 4096
    end
  end
end
