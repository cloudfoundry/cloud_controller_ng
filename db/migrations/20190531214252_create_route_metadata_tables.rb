Sequel.migration do
  change do
    create_table(:route_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :route_labels, :routes)
    end

    create_table(:route_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :route_annotations, :routes)
    end
  end
end
