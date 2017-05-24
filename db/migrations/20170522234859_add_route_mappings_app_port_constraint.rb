Sequel.migration do
  change do
    self[:route_mappings].where(app_port: nil).update(app_port: -1)

    alter_table(:route_mappings) do
      set_column_not_null :app_port
    end
  end
end
