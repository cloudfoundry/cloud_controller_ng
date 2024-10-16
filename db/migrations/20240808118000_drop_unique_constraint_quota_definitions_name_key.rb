Sequel.migration do
  up do
    if database_type == :mysql
      if indexes(:quota_definitions).include?(:name)
        alter_table :quota_definitions do
          # rubocop:disable Sequel/ConcurrentIndex
          drop_index :name, name: :name
          # rubocop:enable Sequel/ConcurrentIndex
        end
      end
    elsif database_type == :postgres
      if indexes(:quota_definitions).include?(:quota_definitions_name_key)
        alter_table :quota_definitions do
          drop_constraint :quota_definitions_name_key
        end
      end
    end
  end

  down do
    if database_type == :mysql
      unless indexes(:quota_definitions).include?(:name)
        alter_table :quota_definitions do
          # rubocop:disable Sequel/ConcurrentIndex
          add_index :name, name: :name, unique: true
          # rubocop:enable Sequel/ConcurrentIndex
        end
      end
    elsif database_type == :postgres
      unless indexes(:quota_definitions).include?(:quota_definitions_name_key)
        alter_table :quota_definitions do
          add_unique_constraint :name, name: :quota_definitions_name_key
        end
      end
    end
  end
end
