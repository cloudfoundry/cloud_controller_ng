Sequel.migration do
  change do
    create_table(:organization_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :organization_annotations, :organizations)
    end
  end
end
