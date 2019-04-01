Sequel.migration do
  change do
    create_table(:droplet_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :droplet_labels, :droplets)
    end
  end
end
