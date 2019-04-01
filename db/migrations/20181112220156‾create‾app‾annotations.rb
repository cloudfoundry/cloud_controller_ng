Sequel.migration do
  change do
    create_table(:app_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :app_annotations, :apps)
    end
  end
end
