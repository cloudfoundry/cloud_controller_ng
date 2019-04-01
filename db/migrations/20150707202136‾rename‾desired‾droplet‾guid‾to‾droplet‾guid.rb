Sequel.migration do
  change do
    alter_table :apps_v3 do
      rename_column :desired_droplet_guid, :droplet_guid
    end
  end
end
