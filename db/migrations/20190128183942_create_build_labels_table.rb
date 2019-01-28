Sequel.migration do
  change do
    create_table(:build_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :build_labels, :builds)
    end
  end
end
