# Unique index in MySQL allows duplicate null values i.e. one null
# value is not the same as another. This means that we cannot really
# use the tuple: [:space_id, :name, :deleted_at] as a unique index
# because deleted_at is null when apps are not deleted, and MySQL
# allows duplicate not-deleted apps in the table.
Sequel.migration do
  change do
    alter_table :apps do
      add_column :not_deleted, TrueClass, default: true
      add_index [:space_id, :name, :not_deleted], unique: true
      drop_index [:space_id, :name]
    end
  end
end
