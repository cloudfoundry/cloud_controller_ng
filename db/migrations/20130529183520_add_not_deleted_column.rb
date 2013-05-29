Sequel.migration do
  change do
    alter_table :apps do
      add_column :not_deleted, "Boolean", :default => true
      add_index [:space_id, :name, :not_deleted], :unique => true
      drop_index [:space_id, :name]
    end
  end
end
