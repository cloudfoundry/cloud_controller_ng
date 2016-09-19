Sequel.migration do
  up do
    alter_table :tasks do
      drop_foreign_key [:droplet_guid], :name=>:fk_tasks_droplet_guid
    end
  end

  down do
    alter_table :tasks do
      foreign_key [:droplet_guid], :droplets, key: :guid, name: :fk_tasks_droplet_guid
    end
  end
end
