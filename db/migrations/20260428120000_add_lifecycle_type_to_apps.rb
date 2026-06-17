Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    if database_type == :postgres
      add_column :apps, :lifecycle_type, String, null: true, size: 255, if_not_exists: true
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :apps, :lifecycle_type, name: :apps_lifecycle_type_index, concurrently: true, if_not_exists: true
      end
    else
      # MySQL
      add_column :apps, :lifecycle_type, String, null: true, size: 255 unless schema(:apps).map(&:first).include?(:lifecycle_type)
      add_index :apps, :lifecycle_type, name: :apps_lifecycle_type_index, concurrently: false unless indexes(:apps).include?(:apps_lifecycle_type_index)
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :apps, :lifecycle_type, name: :apps_lifecycle_type_index, concurrently: true, if_exists: true
      end
      drop_column :apps, :lifecycle_type, if_exists: true
    else
      # MySQL
      drop_index :apps, :lifecycle_type, name: :apps_lifecycle_type_index, concurrently: false if indexes(:apps).include?(:apps_lifecycle_type_index)
      drop_column :apps, :lifecycle_type if schema(:apps).map(&:first).include?(:lifecycle_type)
    end
  end
end
