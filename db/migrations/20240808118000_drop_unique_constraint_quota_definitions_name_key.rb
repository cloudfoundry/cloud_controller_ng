Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    if self.class.name.match?(/mysql/i)
      VCAP::Migration.with_concurrent_timeout(self) do
        alter_table :quota_definitions do
          drop_constraint :name
        end
      end
    elsif self.class.name.match?(/postgres/i)
      VCAP::Migration.with_concurrent_timeout(self) do
        alter_table :quota_definitions do
          drop_constraint :quota_definitions_name_key
        end
      end
    end
  end

  down do
    if self.class.name.match?(/mysql/i)
      VCAP::Migration.with_concurrent_timeout(self) do
        # mysql 5 is not so smart as mysql 8, prevent Mysql2::Error: Duplicate key name 'name'
        alter_table :quota_definitions do
          # rubocop:disable Sequel/ConcurrentIndex
          drop_index :name, name: :name if @db.indexes(:quota_definitions).include?(:name)
          # rubocop:enable Sequel/ConcurrentIndex
        end

        alter_table :quota_definitions do
          add_unique_constraint :name, name: :name
        end
      end
    elsif self.class.name.match?(/postgres/i)
      VCAP::Migration.with_concurrent_timeout(self) do
        alter_table :quota_definitions do
          add_unique_constraint :name, name: :quota_definitions_name_key
        end
      end
    end
  end
end
