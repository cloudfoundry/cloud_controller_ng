Sequel.migration do
  up do
    if self.class.name.match?(/mysql/i)
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
