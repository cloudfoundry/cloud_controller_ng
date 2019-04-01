Sequel.migration do
  change do
    alter_table :droplets do
      add_index [:guid, :droplet_hash], name: :droplets_guid_droplet_hash_index
    end
  end
end
