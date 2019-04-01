Sequel.migration do
  change do
    create_table(:droplet_annotations) do
      VCAP::Migration.common(self)
      VCAP::Migration.annotations_common(self, :droplet_annotations, :droplets)
    end
  end
end
