Sequel.migration do
  change do
    alter_table(:route_mappings) do
      set_column_default(:app_port, -1)
    end

    route_mappings_ids_to_keep = self[:route_mappings].where(app_port: nil).group_by(:app_guid, :route_guid, :process_type).select(Sequel.function(:min, :id))

    self[:route_mappings].exclude(id: route_mappings_ids_to_keep).where(app_port: nil).each do |row|
      self[:route_mappings].where(id: row[:id]).delete
    end

    self[:route_mappings].where(app_port: nil).update(app_port: -1)
  end
end
