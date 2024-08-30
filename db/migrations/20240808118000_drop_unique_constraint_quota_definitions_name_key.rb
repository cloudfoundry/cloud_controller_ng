Sequel.migration do
  up do
    if self.class.name.match?(/mysql/i)
      mysql_version = server_version
      if mysql_version < 80_000 # MySQL 5.7 and below
        alter_table :quota_definitions do
          # rubocop:disable Sequel/ConcurrentIndex
          # Drop the index only for MySQL 5.7
          drop_index :name, name: :name if @db.indexes(:quota_definitions).include?(:name)
          # rubocop:enable Sequel/ConcurrentIndex
        end
      end
      alter_table :quota_definitions do
        drop_constraint :name, if_exists: true
      end
    elsif self.class.name.match?(/postgres/i)
      alter_table :quota_definitions do
        drop_constraint :quota_definitions_name_key, if_exists: true
      end
    end
  end

  down do
    if self.class.name.match?(/mysql/i)
      # mysql 5 is not so smart as mysql 8, prevent Mysql2::Error: Duplicate key name 'name'
      alter_table :quota_definitions do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index :name, name: :name if @db.indexes(:quota_definitions).include?(:name)
        # rubocop:enable Sequel/ConcurrentIndex
      end
      alter_table :quota_definitions do
        add_unique_constraint :name, name: :name, if_not_exists: true
      end
    elsif self.class.name.match?(/postgres/i)
      alter_table :quota_definitions do
        add_unique_constraint :name, name: :quota_definitions_name_key, if_not_exists: true
      end
    end
  end
end
