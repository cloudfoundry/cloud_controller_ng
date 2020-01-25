Sequel.migration do
  change do
    create_table(:service_offering_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_offering_labels, :services)
    end

    create_table(:service_offering_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_offering_annotations, :services)
    end
  end
end
