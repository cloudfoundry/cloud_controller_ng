Sequel.migration do
  change do
    create_table(:space_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :space_annotations, :spaces)
    end
  end
end
