Sequel.migration do
  change do
    alter_table :apps_v3 do
      if Sequel::Model.db.database_type == :mssql
        rename_column :desired_droplet_guid, 'DROPLET_GUID'
      else
        rename_column :desired_droplet_guid, :droplet_guid
      end
    end
  end
end
