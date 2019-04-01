Sequel.migration do
  up do
    create_table :droplets do
      VCAP::Migration.common(self)
      Integer :app_id, null: false
      String :droplet_hash, null: false
      index :app_id
    end

    # run "INSERT INTO droplets (app_id, droplet_hash) SELECT id, droplet_hash FROM apps WHERE droplet_hash IS NOT NULL"
  end

  down do
    drop_table :droplets
  end
end
