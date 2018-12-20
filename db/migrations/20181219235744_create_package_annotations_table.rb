Sequel.migration do
  change do
    create_table(:package_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :package_annotations, :packages)
    end
  end
end
