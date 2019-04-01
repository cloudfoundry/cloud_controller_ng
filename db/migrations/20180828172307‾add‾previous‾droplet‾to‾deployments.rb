Sequel.migration do
  change do
    add_column :deployments, :previous_droplet_guid, String, size: 255
  end
end
