Sequel.migration do
  change do
    add_index :droplets, :droplet_hash
  end
end
