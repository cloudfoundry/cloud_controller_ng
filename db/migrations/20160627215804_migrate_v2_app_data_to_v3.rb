Sequel.migration do
  up do
    alter_table(:v3_droplets) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:packages) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:apps) do
      drop_foreign_key [:app_guid]
      drop_index :app_guid
      drop_foreign_key [:space_id]
      drop_foreign_key [:stack_id], name: :fk_apps_stack_id
      drop_index [:name, :space_id], name: :apps_space_id_name_nd_idx
    end
    alter_table(:route_mappings) do
      drop_foreign_key [:app_guid]
    end
    alter_table(:v3_service_bindings) do
      drop_foreign_key [:app_id]
    end
    alter_table(:tasks) do
      drop_foreign_key [:app_id]
      drop_foreign_key [:droplet_id]
    end

    run 'DELETE FROM apps_routes WHERE app_id IN (SELECT id FROM apps WHERE app_guid IS NOT NULL);'
    run 'DELETE FROM apps WHERE app_guid IS NOT NULL;'  #THIS WILL NOT CREATE APP USAGE EVENTS
    self[:route_mappings].truncate  # what about the v2 route mappings that get created?
    self[:v3_droplets].truncate
    self[:package_docker_data].truncate
    self[:packages].truncate
    self[:buildpack_lifecycle_data].truncate
    self[:v3_service_bindings].truncate  #THIS WILL NOT REMOVE BINDINGS FROM THE BROKER OR CREATE SERVICE USAGE EVENTS
    self[:apps_v3].truncate

    rename_table :apps, :processes
    rename_table :apps_v3, :apps

    alter_table(:processes) do
      add_index :app_guid
      add_foreign_key [:app_guid], :apps, key: :guid
    end
    alter_table(:packages) do
      add_foreign_key [:app_guid], :apps, key: :guid
    end
    alter_table(:route_mappings) do
      add_foreign_key [:app_guid], :apps, key: :guid
    end
    alter_table(:v3_droplets) do
      add_foreign_key [:app_guid], :apps, key: :guid
    end
    alter_table(:v3_service_bindings) do
      add_foreign_key [:app_id], :apps, key: :id   # this is by id instead of guid
    end
    alter_table(:tasks) do
      add_foreign_key [:app_id], :apps, key: :id   # this is by id instead of guid
      add_foreign_key [:droplet_id], :v3_droplets, key: :id   # this is by id instead of guid
    end

    run <<-SQL
        INSERT INTO apps (guid, name, salt, encrypted_environment_variables, created_at, updated_at, space_guid)
        SELECT p.guid, p.name, p.salt, p.encrypted_environment_json, p.created_at, p.updated_at, s.guid
        FROM processes as p, spaces as s
        WHERE p.space_id = s.id
    SQL

    run <<-SQL
        UPDATE processes SET app_guid=guid
    SQL

    alter_table(:buildpack_lifecycle_data) do
      drop_index(:guid)
      set_column_allow_null(:guid)
    end

    run <<-SQL
        INSERT INTO buildpack_lifecycle_data (app_guid, stack)
        SELECT processes.guid, stacks.name
        FROM processes, stacks
        WHERE docker_image is NULL AND stacks.id = processes.stack_id
    SQL

    run <<-SQL
        UPDATE buildpack_lifecycle_data
        SET buildpack=(
          SELECT buildpacks.name
          FROM buildpacks
            JOIN processes ON processes.admin_buildpack_id = buildpacks.id
          WHERE processes.admin_buildpack_id IS NOT NULL AND processes.guid=buildpack_lifecycle_data.app_guid
        )
    SQL

    run <<-SQL
        UPDATE buildpack_lifecycle_data
        SET buildpack=(
          SELECT processes.buildpack
          FROM processes
          WHERE processes.admin_buildpack_id IS NULL AND processes.guid=buildpack_lifecycle_data.app_guid
        )
        WHERE buildpack IS NULL
    SQL

    if self.class.name.match(/mysql/i)
      run 'update buildpack_lifecycle_data set guid=UUID();'
    elsif self.class.name.match(/postgres/i)
      run 'update buildpack_lifecycle_data set guid=get_uuid();'
    end

    alter_table(:buildpack_lifecycle_data) do
      set_column_not_null :guid
      add_index :guid, unique: true, name: :buildpack_lifecycle_data_guid_index
    end

    alter_table(:processes) do
      drop_column :name
      drop_column :encrypted_environment_json
      drop_column :salt
      drop_column :buildpack
      drop_column :space_id
      drop_column :stack_id
      drop_column :admin_buildpack_id
    end
  end
end
