Sequel.migration do
  change do
    create_table(:revision_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :revision_labels, :revisions)
    end
  end
end
