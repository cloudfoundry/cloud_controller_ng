Sequel.migration do
  up do
    alter_table :domains do
      add_column :enforce_route_policies, :boolean, default: false, null: false unless @db.schema(:domains).map(&:first).include?(:enforce_route_policies)
      add_column :route_policies_scope, String, null: true, size: 255 unless @db.schema(:domains).map(&:first).include?(:route_policies_scope)
    end
  end

  down do
    alter_table :domains do
      drop_column :enforce_route_policies if @db.schema(:domains).map(&:first).include?(:enforce_route_policies)
      drop_column :route_policies_scope if @db.schema(:domains).map(&:first).include?(:route_policies_scope)
    end
  end
end
