Sequel.migration do
  change do
    create_table(:route_binding_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :route_binding_labels, :route_bindings)
    end

    create_table(:route_binding_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :route_binding_annotations, :route_bindings)
    end
  end
end
