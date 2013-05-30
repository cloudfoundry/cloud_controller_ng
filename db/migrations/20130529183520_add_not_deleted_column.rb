Sequel.migration do
  change do
    alter_table :apps do
      add_column :not_deleted, TrueClass, :default => true
      add_index [:space_id, :name, :not_deleted], :unique => true, :case_insensitive => [:name], :name => :apps_space_name_nd_index
      drop_index [:space_id, :name]
    end
  end
end
