Sequel.migration do
  change do
    alter_table :v3_droplets do
      add_column :failure_reason, String, null: true, text: true
    end
  end
end
