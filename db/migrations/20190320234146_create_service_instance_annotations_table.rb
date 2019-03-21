Sequel.migration do
  change do
    create_table(:service_instance_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_instance_annotations, :service_instances)
    end
  end
end
