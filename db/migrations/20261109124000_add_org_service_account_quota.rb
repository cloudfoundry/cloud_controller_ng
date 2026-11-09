Sequel.migration do
  change do
    alter_table(:quota_definitions) { add_column :total_service_accounts, Integer, null: false, default: -1 }
  end
end
