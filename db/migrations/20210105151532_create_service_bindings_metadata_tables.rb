Sequel.migration do
  change do
    create_table(:service_binding_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :service_binding_labels, :service_bindings)
    end

    create_table(:service_binding_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :service_binding_annotations, :service_bindings)
    end
  end
end
