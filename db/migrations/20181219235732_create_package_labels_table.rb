Sequel.migration do
  change do
    create_table(:package_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :package_labels, :packages)
    end
  end
end
