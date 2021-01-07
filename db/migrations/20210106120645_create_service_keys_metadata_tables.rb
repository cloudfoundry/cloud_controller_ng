Sequel.migration do
  change do
    create_table(:service_key_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_key_labels, :service_keys)
    end

    create_table(:service_key_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_key_annotations, :service_keys)
    end
  end
end
