Sequel.migration do
  change do
    create_table(:service_instance_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_instance_labels, :service_instances)
    end
  end
end
