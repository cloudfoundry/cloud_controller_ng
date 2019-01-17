Sequel.migration do
  change do
    create_table(:revision_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :revision_annotations, :revisions)
    end
  end
end
