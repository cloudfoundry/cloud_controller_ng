Sequel.migration do
  up do
    alter_table :domains do
      add_column :enforce_access_rules, :boolean, default: false, null: false unless @db.schema(:domains).map(&:first).include?(:enforce_access_rules)
      add_column :access_rules_scope, String, null: true, size: 255 unless @db.schema(:domains).map(&:first).include?(:access_rules_scope)
    end
  end

  down do
    alter_table :domains do
      drop_column :enforce_access_rules if @db.schema(:domains).map(&:first).include?(:enforce_access_rules)
      drop_column :access_rules_scope if @db.schema(:domains).map(&:first).include?(:access_rules_scope)
    end
  end
end
