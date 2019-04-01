Sequel.migration do
  change do
    create_table(:build_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :build_annotations, :builds)
    end
  end
end
