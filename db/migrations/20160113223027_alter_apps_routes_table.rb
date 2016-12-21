Sequel.migration do
  up do
    alter_table :apps_routes do
      # mysql requires foreign key to be dropped before index
      drop_foreign_key [:app_id], name: :fk_apps_routes_app_id
      drop_foreign_key [:route_id], name: :fk_apps_routes_route_id

      drop_index [:app_id, :route_id], name: :ar_app_id_route_id_index

      add_foreign_key [:app_id], :apps, name: :fk_apps_routes_app_id
      add_foreign_key [:route_id], :routes, name: :fk_apps_routes_route_id

      add_primary_key :id
      if Sequel::Model.db.database_type == :mssql
        add_column :created_at, :datetime, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_column :updated_at, :datetime
      else
        add_column :created_at, :timestamp, null: false, default: Sequel::CURRENT_TIMESTAMP
        add_column :updated_at, :timestamp
      end
      add_column :app_port, Integer
      add_column :guid, String
    end

    if self.class.name =~ /mysql/i
      run 'update apps_routes set guid=UUID();'
    elsif self.class.name =~ /postgres/i
      run 'CREATE OR REPLACE FUNCTION get_uuid()
      RETURNS TEXT AS $$
      BEGIN
        BEGIN
          RETURN gen_random_uuid();
        EXCEPTION WHEN OTHERS THEN
          RETURN uuid_generate_v4();
        END;
       END;
       $$ LANGUAGE plpgsql;'

      run 'update apps_routes set guid=get_uuid();'
    elsif Sequel::Model.db.database_type == :mssql
      run 'update apps_routes set guid=NEWID();'
    end

    alter_table :apps_routes do
      add_index :guid, unique: true, name: :apps_routes_guid_index
      add_index :created_at, name: :apps_routes_created_at_index
      add_index :updated_at, name: :apps_routes_updated_at_index
    end
  end

  down do
    alter_table :apps_routes do
      drop_index :guid, name: :apps_routes_guid_index
      drop_index :updated_at, name: :apps_routes_updated_at_index
      drop_index :created_at, name: :apps_routes_created_at_index

      drop_column :guid
      drop_column :app_port
      drop_column :updated_at
      drop_column :created_at
      drop_column :id

      add_index [:app_id, :route_id], unique: true, name: :ar_app_id_route_id_index
    end
    if self.class.name =~ /postgres/i
      run 'drop function if exists get_uuid();'
    end
  end
end
