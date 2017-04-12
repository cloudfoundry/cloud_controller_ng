Sequel.migration do
  transaction

  up do
    collate_opts = {}
    dbtype = if self.class.name =~ /mysql/i
               collate_opts[:collate] = :utf8_bin
               'mysql'
             elsif self.class.name =~ /postgres/i
               'postgres'
             elsif Sequel::Model.db.database_type == :mssql
               'mssql'
             else
               raise 'unknown database'
             end

    ####
    ##  App usage events - Insert STOP events for v3 created processes that will be removed
    ####
    if Sequel::Model.db.database_type == :mssql
      generate_stop_events_query = <<-SQL
      INSERT INTO APP_USAGE_EVENTS
        (GUID, CREATED_AT, INSTANCE_COUNT, MEMORY_IN_MB_PER_INSTANCE, STATE, APP_GUID, APP_NAME, SPACE_GUID, SPACE_NAME, ORG_GUID, BUILDPACK_GUID, BUILDPACK_NAME, PACKAGE_STATE, PARENT_APP_NAME, PARENT_APP_GUID, PROCESS_TYPE, TASK_GUID, TASK_NAME, PACKAGE_GUID, PREVIOUS_STATE, PREVIOUS_PACKAGE_STATE, PREVIOUS_MEMORY_IN_MB_PER_INSTANCE, PREVIOUS_INSTANCE_COUNT)
      SELECT %s, %s(), P.INSTANCES, P.MEMORY, 'STOPPED', P.GUID, P.NAME, S.GUID, S.NAME, O.GUID, D.BUILDPACK_RECEIPT_BUILDPACK_GUID, D.BUILDPACK_RECEIPT_BUILDPACK, P.PACKAGE_STATE, A.NAME, A.GUID, P.TYPE, NULL, NULL, PKG.GUID, 'STARTED', P.PACKAGE_STATE, P.MEMORY, P.INSTANCES
        FROM APPS AS P
          INNER JOIN APPS_V3 AS A ON (A.GUID=P.APP_GUID)
          INNER JOIN SPACES AS S ON (S.GUID=A.SPACE_GUID)
          INNER JOIN ORGANIZATIONS AS O ON (O.ID=S.ORGANIZATION_ID)
          INNER JOIN PACKAGES AS PKG ON (A.GUID=PKG.APP_GUID)
          INNER JOIN V3_DROPLETS AS D ON (A.GUID=D.APP_GUID)
          INNER JOIN BUILDPACK_LIFECYCLE_DATA AS L ON (D.GUID=L.DROPLET_GUID)
        WHERE P.STATE='STARTED'
      SQL
    else
      generate_stop_events_query = <<-SQL
      INSERT INTO app_usage_events
        (guid, created_at, instance_count, memory_in_mb_per_instance, state, app_guid, app_name, space_guid, space_name, org_guid, buildpack_guid, buildpack_name, package_state, parent_app_name, parent_app_guid, process_type, task_guid, task_name, package_guid, previous_state, previous_package_state, previous_memory_in_mb_per_instance, previous_instance_count)
      SELECT %s, %s(), p.instances, p.memory, 'STOPPED', p.guid, p.name, s.guid, s.name, o.guid, d.buildpack_receipt_buildpack_guid, d.buildpack_receipt_buildpack, p.package_state, a.name, a.guid, p.type, NULL, NULL, pkg.guid, 'STARTED', p.package_state, p.memory, p.instances
        FROM apps as p
          INNER JOIN apps_v3 as a ON (a.guid=p.app_guid)
          INNER JOIN spaces as s ON (s.guid=a.space_guid)
          INNER JOIN organizations as o ON (o.id=s.organization_id)
          INNER JOIN packages as pkg ON (a.guid=pkg.app_guid)
          INNER JOIN v3_droplets as d ON (a.guid=d.app_guid)
          INNER JOIN buildpack_lifecycle_data as l ON (d.guid=l.droplet_guid)
        WHERE p.state='STARTED'
      SQL
    end

    if dbtype == 'mysql'
      run sprintf(generate_stop_events_query, 'UUID()', 'now')
    elsif dbtype == 'postgres'
      run sprintf(generate_stop_events_query, 'get_uuid()', 'now')
    elsif dbtype == 'mssql'
      run sprintf(generate_stop_events_query, 'NEWID()', 'GETDATE')
    end

    ###
    ##  remove V3 data
    ###

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
    drop_table(:v3_service_bindings)
    drop_table(:tasks)
    drop_table(:package_docker_data)
    drop_table(:v3_droplets)
    drop_table(:route_mappings)

    if Sequel::Model.db.database_type == :mssql
      run 'DELETE FROM DROPLETS WHERE APP_ID IN (SELECT ID FROM APPS WHERE APP_GUID IS NOT NULL);'
      run 'DELETE FROM APPS_ROUTES WHERE APP_ID IN (SELECT ID FROM APPS WHERE APP_GUID IS NOT NULL);'
      run 'DELETE FROM APPS WHERE APP_GUID IS NOT NULL OR DELETED_AT IS NOT NULL;'
    else
      run 'DELETE FROM droplets WHERE app_id IN (SELECT id FROM apps WHERE app_guid IS NOT NULL);'
      run 'DELETE FROM apps_routes WHERE app_id IN (SELECT id FROM apps WHERE app_guid IS NOT NULL);'
      run 'DELETE FROM apps WHERE app_guid IS NOT NULL OR deleted_at IS NOT NULL;'
    end

    self[:packages].truncate
    self[:buildpack_lifecycle_data].truncate
    self[:apps_v3].truncate

    ####
    ##  Alter tables to match v3 format
    ####

    alter_table(:buildpack_lifecycle_data) do
      add_column :encrypted_buildpack_url, String
      add_column :encrypted_buildpack_url_salt, String
      add_column :admin_buildpack_name, String
      add_index :admin_buildpack_name, name: :buildpack_lifecycle_data_admin_buildpack_name_index

      drop_column :encrypted_buildpack
      drop_column :salt

      drop_index(:guid)
      set_column_allow_null(:guid)
    end

    rename_table :apps, :processes
    rename_table :apps_v3, :apps

    alter_table(:processes) do
      add_index :app_guid, name: :processes_app_guid_index
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_processes_app_guid
    end

    alter_table(:packages) do
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_packages_app_guid

      drop_column :url
      add_column :docker_image, String, type: :text
    end

    alter_table :droplets do
      add_column :state, String
      add_index :state, name: :droplets_state_index
      add_column :process_types, String, type: :text
      add_column :error_id, String
      add_column :error_description, String, type: :text
      add_column :encrypted_environment_variables, String, text: true
      add_column :salt, String
      add_column :staging_memory_in_mb, Integer
      add_column :staging_disk_in_mb, Integer

      add_column :buildpack_receipt_stack_name, String
      add_column :buildpack_receipt_buildpack, String
      add_column :buildpack_receipt_buildpack_guid, String
      add_column :buildpack_receipt_detect_output, String
      add_column :docker_receipt_image, String

      add_column :package_guid, String
      add_index :package_guid, name: :package_guid_index

      add_column :app_guid, String
      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_droplets_app_guid

      set_column_allow_null(:droplet_hash)
    end

    alter_table(:apps_routes) do
      add_column :app_guid, String, collate_opts
      add_column :route_guid, String, collate_opts
      add_column :process_type, String
      add_index :process_type, name: :route_mappings_process_type_index

      drop_foreign_key [:route_id]
      drop_foreign_key [:app_id]
      drop_constraint :apps_routes_app_id_route_id_app_port_key, type: :unique
    end

    alter_table(:service_bindings) do
      add_column :app_guid, String
      add_column :service_instance_guid, String
      add_column :type, String

      drop_foreign_key [:service_instance_id]
      drop_foreign_key [:app_id]
    end

    create_table :tasks do
      VCAP::Migration.common(self)

      String :name, case_insensitive: true, null: false
      index :name, name: :tasks_name_index
      String :command, null: false, text: true
      String :state, null: false
      index :state, name: :tasks_state_index
      Integer :memory_in_mb, null: true
      String :encrypted_environment_variables, text: true, null: true
      String :salt, null: true
      String :failure_reason, null: true, size: 4096

      String :app_guid, null: false
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_tasks_app_guid

      String :droplet_guid, null: false
      foreign_key [:droplet_guid], :droplets, key: :guid, name: :fk_tasks_droplet_guid

      if self.class.name =~ /mysql/i
        table_name = tables.find { |t| t =~ /tasks/ }
        run "ALTER TABLE `#{table_name}` CONVERT TO CHARACTER SET utf8;"
      end
    end

    ####
    ## Migrate data
    ####

    transaction do
      ####
      ## Fill in v3 apps table data
      ###
      if Sequel::Model.db.database_type != :mssql
        run <<-SQL
          INSERT INTO apps (guid, name, salt, encrypted_environment_variables, created_at, updated_at, space_guid, desired_state)
          SELECT p.guid, p.name, p.salt, p.encrypted_environment_json, p.created_at, p.updated_at, s.guid, p.state
          FROM processes as p, spaces as s
          WHERE p.space_id = s.id
          ORDER BY p.id
        SQL

        run <<-SQL
          UPDATE processes SET app_guid=guid
        SQL

        #####
        ## Create lifecycle data for buildpack apps
        ####

        run <<-SQL
          INSERT INTO buildpack_lifecycle_data (app_guid, stack)
          SELECT processes.guid, stacks.name
          FROM processes, stacks
          WHERE docker_image is NULL AND stacks.id = processes.stack_id
        SQL

        run <<-SQL
          UPDATE buildpack_lifecycle_data
          SET
            admin_buildpack_name=(
              SELECT buildpacks.name
              FROM buildpacks
                JOIN processes ON processes.admin_buildpack_id = buildpacks.id
              WHERE processes.admin_buildpack_id IS NOT NULL AND processes.guid=buildpack_lifecycle_data.app_guid
            ),
            encrypted_buildpack_url=(
              SELECT processes.encrypted_buildpack
              FROM processes
              WHERE processes.admin_buildpack_id IS NULL AND processes.guid=buildpack_lifecycle_data.app_guid
            ),
            encrypted_buildpack_url_salt=(
              SELECT processes.buildpack_salt
              FROM processes
              WHERE processes.admin_buildpack_id IS NULL AND processes.guid=buildpack_lifecycle_data.app_guid
            )
        SQL

        #####
        ## Fill in packages data
        ####

        run <<-SQL
          INSERT INTO packages (guid, type, package_hash, state, error, app_guid)
          SELECT guid, 'bits', package_hash, 'READY', NULL, guid
            FROM processes
          WHERE package_hash IS NOT NULL AND docker_image IS NULL
        SQL

        run <<-SQL
          INSERT INTO packages (guid, type, state, error, app_guid, docker_image)
          SELECT  guid, 'docker', 'READY', NULL, guid, docker_image
            FROM processes
          WHERE docker_image IS NOT NULL
        SQL

        ####
        ## Fill in droplets data
        ####

        # backfill any v2 droplets that do not exist due to lazy backfilling in v2 droplets.  it is unlikely there are
        # any of these, but possible in very old CF deployments
        run <<-SQL
          INSERT INTO droplets (guid, app_id, droplet_hash, detected_start_command)
          SELECT processes.guid, processes.id, processes.droplet_hash, '' AS detected_start_command
            FROM processes
          WHERE processes.droplet_hash IS NOT NULL
            AND processes.id IN ( SELECT processes.id FROM processes LEFT JOIN droplets ON processes.id = droplets.app_id WHERE droplets.id IS NULL)
        SQL

        # pruning will not delete from the blobstore

        # prune orphaned droplets
        run <<-SQL
          DELETE FROM droplets WHERE NOT EXISTS (SELECT 1 FROM processes WHERE droplets.app_id = processes.id)
        SQL
      else
        run <<-SQL
        INSERT INTO APPS (GUID, NAME, SALT, ENCRYPTED_ENVIRONMENT_VARIABLES, CREATED_AT, UPDATED_AT, SPACE_GUID, DESIRED_STATE)
        SELECT P.GUID, P.NAME, P.SALT, P.ENCRYPTED_ENVIRONMENT_JSON, P.CREATED_AT, P.UPDATED_AT, S.GUID, P.STATE
        FROM PROCESSES AS P, SPACES AS S
        WHERE P.SPACE_ID = S.ID
        ORDER BY P.ID
        SQL

        run <<-SQL
        UPDATE PROCESSES SET APP_GUID=GUID
        SQL

        #####
        ## Create lifecycle data for buildpack apps
        ####

        run <<-SQL
        INSERT INTO BUILDPACK_LIFECYCLE_DATA (APP_GUID, STACK)
        SELECT PROCESSES.GUID, STACKS.NAME
        FROM PROCESSES, STACKS
        WHERE DOCKER_IMAGE IS NULL AND STACKS.ID = PROCESSES.STACK_ID
        SQL

        run <<-SQL
        UPDATE BUILDPACK_LIFECYCLE_DATA
        SET
          ADMIN_BUILDPACK_NAME=(
            SELECT BUILDPACKS.NAME
            FROM BUILDPACKS
              JOIN PROCESSES ON PROCESSES.ADMIN_BUILDPACK_ID = BUILDPACKS.ID
            WHERE PROCESSES.ADMIN_BUILDPACK_ID IS NOT NULL AND PROCESSES.GUID=BUILDPACK_LIFECYCLE_DATA.APP_GUID
          ),
          ENCRYPTED_BUILDPACK_URL=(
            SELECT PROCESSES.ENCRYPTED_BUILDPACK
            FROM PROCESSES
            WHERE PROCESSES.ADMIN_BUILDPACK_ID IS NULL AND PROCESSES.GUID=BUILDPACK_LIFECYCLE_DATA.APP_GUID
          ),
          ENCRYPTED_BUILDPACK_URL_SALT=(
            SELECT PROCESSES.BUILDPACK_SALT
            FROM PROCESSES
            WHERE PROCESSES.ADMIN_BUILDPACK_ID IS NULL AND PROCESSES.GUID=BUILDPACK_LIFECYCLE_DATA.APP_GUID
          )
        SQL

        #####
        ## Fill in packages data
        ####

        run <<-SQL
        INSERT INTO PACKAGES (GUID, TYPE, PACKAGE_HASH, STATE, ERROR, APP_GUID)
        SELECT GUID, 'bits', PACKAGE_HASH, 'READY', NULL, GUID
          FROM PROCESSES
        WHERE PACKAGE_HASH IS NOT NULL AND DOCKER_IMAGE IS NULL
        SQL

        run <<-SQL
        INSERT INTO PACKAGES (GUID, TYPE, STATE, ERROR, APP_GUID, DOCKER_IMAGE)
        SELECT  GUID, 'docker', 'READY', NULL, GUID, DOCKER_IMAGE
          FROM PROCESSES
        WHERE DOCKER_IMAGE IS NOT NULL
        SQL

        ####
        ## Fill in droplets data
        ####

        # backfill any v2 droplets that do not exist due to lazy backfilling in v2 droplets.  it is unlikely there are
        # any of these, but possible in very old CF deployments
        run <<-SQL
        INSERT INTO DROPLETS (GUID, APP_ID, DROPLET_HASH, DETECTED_START_COMMAND)
        SELECT PROCESSES.GUID, PROCESSES.ID, PROCESSES.DROPLET_HASH, '' AS DETECTED_START_COMMAND
          FROM PROCESSES
        WHERE PROCESSES.DROPLET_HASH IS NOT NULL
          AND PROCESSES.ID IN ( SELECT PROCESSES.ID FROM PROCESSES LEFT JOIN DROPLETS ON PROCESSES.ID = DROPLETS.APP_ID WHERE DROPLETS.ID IS NULL)
        SQL

        # pruning will not delete from the blobstore

        # prune orphaned droplets
        run <<-SQL
        DELETE FROM DROPLETS WHERE NOT EXISTS (SELECT 1 FROM PROCESSES WHERE DROPLETS.APP_ID = PROCESSES.ID)
        SQL
      end

      # prune additional droplets, each app will have only one droplet
      postgres_prune_droplets_query = <<-SQL
        DELETE FROM droplets
        USING droplets as d
          JOIN processes ON processes.id = d.app_id
        WHERE droplets.id = d.id AND (processes.droplet_hash <> d.droplet_hash OR processes.droplet_hash IS NULL)
      SQL

      mysql_prune_droplets_query = <<-SQL
        DELETE droplets FROM droplets
          JOIN processes ON processes.id = droplets.app_id
        WHERE processes.droplet_hash <> droplets.droplet_hash OR processes.droplet_hash IS NULL
      SQL

      mssql_prune_droplets_query = <<-SQL
        DELETE DROPLETS FROM DROPLETS
          JOIN PROCESSES ON PROCESSES.ID = DROPLETS.APP_ID
        WHERE PROCESSES.DROPLET_HASH <> DROPLETS.DROPLET_HASH OR PROCESSES.DROPLET_HASH IS NULL
      SQL

      if dbtype == 'mysql'
        run mysql_prune_droplets_query

        run <<-SQL
          DELETE a FROM droplets a, droplets b
          WHERE a.app_id=b.app_id AND a.id < b.id
        SQL
      elsif dbtype == 'postgres'
        run postgres_prune_droplets_query

        run <<-SQL
          DELETE FROM droplets a USING droplets b
          WHERE a.app_id = b.app_id AND a.id < b.id
        SQL
      elsif dbtype == 'mssql'
        run mssql_prune_droplets_query

        run <<-SQL
          DELETE A FROM DROPLETS A, DROPLETS B
          WHERE A.APP_ID=B.APP_ID AND A.ID < B.ID
        SQL
      end

      # convert to v3 droplets
      postgres_convert_to_v3_droplets_query = <<-SQL
        UPDATE droplets
        SET
          guid = v2_app.guid,
          state = 'STAGED',
          app_guid = v2_app.guid,
          package_guid = v2_app.guid,
          docker_receipt_image = droplets.cached_docker_image,
          process_types = '{"web":"' || droplets.detected_start_command || '"}',
          buildpack_receipt_buildpack = v2_app.detected_buildpack_name,
          buildpack_receipt_buildpack_guid = v2_app.detected_buildpack_guid,
          buildpack_receipt_detect_output = v2_app.detected_buildpack
        FROM processes AS v2_app
        WHERE v2_app.id = droplets.app_id
      SQL

      mysql_convert_to_v3_droplets_query = <<-SQL
        UPDATE droplets
        JOIN processes as v2_app
          ON v2_app.id = droplets.app_id
        SET
          droplets.guid = v2_app.guid,
          droplets.state = 'STAGED',
          droplets.app_guid = v2_app.guid,
          droplets.package_guid = v2_app.guid,
          droplets.docker_receipt_image = droplets.cached_docker_image,
          droplets.process_types = CONCAT('{"web":"', droplets.detected_start_command, '"}'),
          droplets.buildpack_receipt_buildpack = v2_app.detected_buildpack_name,
          droplets.buildpack_receipt_buildpack_guid = v2_app.detected_buildpack_guid,
          droplets.buildpack_receipt_detect_output = v2_app.detected_buildpack
      SQL

      mssql_convert_to_v3_droplets_query = <<-SQL
        UPDATE DROPLETS
        SET
          GUID = V2_APP.GUID,
          STATE = 'STAGED',
          APP_GUID = V2_APP.GUID,
          PACKAGE_GUID = V2_APP.GUID,
          DOCKER_RECEIPT_IMAGE = DROPLETS.CACHED_DOCKER_IMAGE,
          PROCESS_TYPES = CONCAT('{"web":"', DROPLETS.DETECTED_START_COMMAND, '"}'),
          BUILDPACK_RECEIPT_BUILDPACK = V2_APP.DETECTED_BUILDPACK_NAME,
          BUILDPACK_RECEIPT_BUILDPACK_GUID = V2_APP.DETECTED_BUILDPACK_GUID,
          BUILDPACK_RECEIPT_DETECT_OUTPUT = V2_APP.DETECTED_BUILDPACK
        FROM PROCESSES AS V2_APP
        WHERE V2_APP.ID = DROPLETS.APP_ID
      SQL

      if dbtype == 'mysql'
        run mysql_convert_to_v3_droplets_query
      elsif dbtype == 'postgres'
        run postgres_convert_to_v3_droplets_query
      elsif dbtype == 'mssql'
        run mssql_convert_to_v3_droplets_query
      end

      # add lifecycle data to buildpack droplets
      if Sequel::Model.db.database_type != :mssql
        run <<-SQL
          INSERT INTO buildpack_lifecycle_data (droplet_guid)
          SELECT droplets.guid
            FROM processes, droplets
          WHERE processes.docker_image is NULL AND droplets.app_guid = processes.guid
        SQL
      else
        run <<-SQL
          INSERT INTO BUILDPACK_LIFECYCLE_DATA (DROPLET_GUID)
          SELECT DROPLETS.GUID
            FROM PROCESSES, DROPLETS
          WHERE PROCESSES.DOCKER_IMAGE IS NULL AND DROPLETS.APP_GUID = PROCESSES.GUID
        SQL
      end

      # set current droplet on v3 app
      postgres_set_current_droplet_query = <<-SQL
        UPDATE apps
          SET droplet_guid = droplets.guid
        FROM droplets
          WHERE droplets.app_guid = apps.guid
      SQL

      mysql_set_current_droplet_query = <<-SQL
        UPDATE apps
        JOIN droplets as current_droplet
          ON apps.guid = current_droplet.app_guid
        JOIN processes as web_process
          ON web_process.app_guid = apps.guid AND web_process.type = 'web'
        SET apps.droplet_guid = current_droplet.guid
        WHERE web_process.droplet_hash IS NOT NULL AND current_droplet.droplet_hash = web_process.droplet_hash
      SQL

      mssql_set_current_droplet_query = <<-SQL
        UPDATE APPS
          SET DROPLET_GUID = DROPLETS.GUID
        FROM DROPLETS
          WHERE DROPLETS.APP_GUID = APPS.GUID
      SQL

      if dbtype == 'mysql'
        run mysql_set_current_droplet_query
      elsif dbtype == 'postgres'
        run postgres_set_current_droplet_query
      elsif dbtype == 'mssql'
        run mssql_set_current_droplet_query
      end

      ####
      ## Fill in guids for buildpack_lifecycle_data inserts done for apps and droplets
      ####

      if self.class.name =~ /mysql/i
        run 'update buildpack_lifecycle_data set guid=UUID();'
      elsif self.class.name =~ /postgres/i
        run 'update buildpack_lifecycle_data set guid=get_uuid();'
      elsif Sequel::Model.db.database_type == :mssql
        run 'UPDATE BUILDPACK_LIFECYCLE_DATA SET GUID=NEWID();'
      end

      ####
      ## Migrate route mappings
      ####

      if Sequel::Model.db.database_type != :mssql
        run <<-SQL
          UPDATE apps_routes SET
            app_guid = (SELECT processes.guid FROM processes WHERE processes.id=apps_routes.app_id),
            route_guid = (SELECT routes.guid FROM routes WHERE routes.id=apps_routes.route_id),
            process_type = 'web'
        SQL

        run <<-SQL
          UPDATE apps_routes SET app_port=8080 WHERE app_port IS NULL AND EXISTS (SELECT 1 FROM processes WHERE processes.docker_image IS NULL AND processes.id = apps_routes.app_id)
        SQL
      else
        run <<-SQL
          UPDATE APPS_ROUTES SET
            APP_GUID = (SELECT PROCESSES.GUID FROM PROCESSES WHERE PROCESSES.ID=APPS_ROUTES.APP_ID),
            ROUTE_GUID = (SELECT ROUTES.GUID FROM ROUTES WHERE ROUTES.ID=APPS_ROUTES.ROUTE_ID),
            PROCESS_TYPE = 'web'
        SQL

        run <<-SQL
          UPDATE APPS_ROUTES SET APP_PORT=8080 WHERE APP_PORT IS NULL AND EXISTS (SELECT 1 FROM PROCESSES WHERE PROCESSES.DOCKER_IMAGE IS NULL AND PROCESSES.ID = APPS_ROUTES.APP_ID)
        SQL
      end

      if self.class.name =~ /mysql/i
        run 'update apps_routes set guid=UUID() where guid is NULL;'
      elsif self.class.name =~ /postgres/i
        run 'update apps_routes set guid=get_uuid() where guid is NULL;'
      elsif Sequel::Model.db.database_type == :mssql
        run 'UPDATE APPS_ROUTES SET GUID=NEWID() WHERE GUID IS NULL;'
      end

      ####
      ## Migrate service bindings
      ####

      if Sequel::Model.db.database_type != :mssql
        run <<-SQL
          UPDATE service_bindings SET
            app_guid = (SELECT processes.guid FROM processes WHERE processes.id=service_bindings.app_id),
            service_instance_guid = (SELECT service_instances.guid FROM service_instances WHERE service_instances.id=service_bindings.service_instance_id),
            type = 'app'
        SQL
      else
        run <<-SQL
          UPDATE SERVICE_BINDINGS SET
            APP_GUID = (SELECT PROCESSES.GUID FROM PROCESSES WHERE PROCESSES.ID=SERVICE_BINDINGS.APP_ID),
            SERVICE_INSTANCE_GUID = (SELECT SERVICE_INSTANCES.GUID FROM SERVICE_INSTANCES WHERE SERVICE_INSTANCES.ID=SERVICE_BINDINGS.SERVICE_INSTANCE_ID),
            TYPE = 'app'
        SQL
      end
    end

    ####
    ## Remove columns that have moved to other tables
    ##
    ## Re-establish foreign key and null constraints
    ####

    alter_table(:buildpack_lifecycle_data) do
      set_column_not_null :guid
      add_index :guid, unique: true, name: :buildpack_lifecycle_data_guid_index
    end

    alter_table :droplets do
      drop_index :state, name: :droplets_state_index
      set_column_not_null(:state)
      add_index :state, name: :droplets_state_index
      drop_index :app_id, name: :droplets_app_id_index
      drop_column :app_id
      drop_column :cached_docker_image
      drop_column :detected_start_command
    end

    alter_table(:apps_routes) do
      drop_column :route_id
      drop_column :app_id

      set_column_not_null(:app_guid)
      set_column_not_null(:route_guid)
      drop_index :guid, name: :apps_routes_guid_index
      set_column_not_null(:guid)
      add_index :guid, unique: true, name: :apps_routes_guid_index
      # for mysql, which loses collation settings when setting not null constraint
      set_column_type :app_guid, String, collate_opts
      set_column_type :route_guid, String, collate_opts

      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_route_mappings_app_guid
      add_foreign_key [:route_guid], :routes, key: :guid, name: :fk_route_mappings_route_guid

      add_unique_constraint [:app_guid, :route_guid, :process_type, :app_port], name: :route_mappings_app_guid_route_guid_process_type_app_port_key
    end

    rename_table :apps_routes, :route_mappings

    alter_table(:service_bindings) do
      drop_index [:app_id, :service_instance_id], name: :sb_app_id_srv_inst_id_index
      drop_column :service_instance_id
      drop_column :app_id
      drop_column :gateway_name
      drop_column :gateway_data
      drop_column :configuration
      drop_column :binding_options

      set_column_not_null(:app_guid)
      set_column_not_null(:service_instance_guid)

      # for mysql, which loses collation settings when setting not null constraint
      set_column_type :app_guid, String, collate_opts
      set_column_type :service_instance_guid, String, collate_opts

      add_foreign_key [:app_guid], :apps, key: :guid, name: :fk_service_bindings_app_guid
      add_foreign_key [:service_instance_guid], :service_instances, key: :guid, name: :fk_service_bindings_service_instance_guid
    end

    alter_table(:processes) do
      drop_index :name, name: :apps_name_index
      drop_column :name
      drop_column :encrypted_environment_json
      drop_column :salt
      drop_column :encrypted_buildpack
      drop_column :buildpack_salt
      drop_column :space_id
      drop_index :stack_id, name: :apps_stack_id_index
      drop_column :stack_id
      drop_column :admin_buildpack_id
      drop_column :docker_image
      drop_column :package_hash
      drop_column :package_state
      drop_column :droplet_hash
      drop_index :package_pending_since, name: :apps_pkg_pending_since_index
      drop_column :package_pending_since
      drop_column :deleted_at
      drop_column :staging_task_id
      drop_column :detected_buildpack_guid
      drop_column :detected_buildpack_name
      drop_column :staging_failed_reason
      drop_column :staging_failed_description
    end
  end
end
