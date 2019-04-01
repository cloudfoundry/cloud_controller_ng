Sequel.migration do
  change do
    alter_table :organizations do
      add_column :status, String, default: 'active'
    end
  end
end
