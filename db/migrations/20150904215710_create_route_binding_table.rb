Sequel.migration do
  change do
    create_table :route_bindings do
      VCAP::Migration.common(self)

      foreign_key :route_id, :routes

      foreign_key :service_instance_id, :service_instances
    end
  end
end
