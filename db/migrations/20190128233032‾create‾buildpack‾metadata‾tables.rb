Sequel.migration do
  change do
    create_table(:buildpack_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :buildpack_annotations, :buildpacks)
    end

    create_table(:buildpack_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :buildpack_labels, :buildpacks)
    end
  end
end
