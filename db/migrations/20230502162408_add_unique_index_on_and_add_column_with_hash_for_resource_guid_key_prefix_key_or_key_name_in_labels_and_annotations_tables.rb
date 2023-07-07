require 'digest'

Sequel.migration do
  annotaion_tables_to_migrate = {
    app_annotations: 'app_ann',
    build_annotations: 'build_ann',
    buildpack_annotations: 'buildp_ann',
    deployment_annotations: 'depl_ann',
    domain_annotations: 'dom_ann',
    droplet_annotations: 'drop_ann',
    isolation_segment_annotations: 'iso_ann',
    organization_annotations: 'org_ann',
    package_annotations: 'pack_ann',
    process_annotations: 'proc_ann',
    revision_annotations: 'rev_ann',
    route_annotations: 'rt_ann',
    route_binding_annotations: 'rt_bind_ann',
    service_binding_annotations: 'sv_bind_ann',
    service_broker_annotations: 'svbr_ann',
    service_broker_update_request_annotations: 'svcbr_upd_req_ann',
    service_instance_annotations: 'sv_inst_ann',
    service_key_annotations: 'sv_key_ann',
    service_offering_annotations: 'sv_off_ann',
    service_plan_annotations: 'sv_plan_ann',
    space_annotations: 'space_ann',
    stack_annotations: 'stack_ann',
    task_annotations: 'task_ann',
    user_annotations: 'user_ann',
  }
  label_tables_to_migrate = {
    app_labels: 'app_lab',
    build_labels:  'build_lab',
    buildpack_labels: 'buildp_lab',
    deployment_labels: 'depl_lab',
    domain_labels: 'dom_lab',
    droplet_labels: 'drop_lab',
    isolation_segment_labels: 'iso_lab',
    organization_labels: 'org_lab',
    package_labels: 'pack_lab',
    process_labels: 'proc_lab',
    revision_labels: 'rev_lab',
    route_binding_labels: 'rt_bind_lab',
    route_labels: 'rt_lab',
    service_binding_labels: 'sv_bind_lab',
    service_broker_labels: 'svbr_lab',
    service_broker_update_request_labels: 'svbr_upd_req_lab',
    service_instance_labels: 'sv_inst_lab',
    service_key_labels: 'sv_key_lab',
    service_offering_labels: 'sv_off_lab',
    service_plan_labels: 'sv_plan_lab',
    space_labels: 'space_lab',
    stack_labels: 'stack_lab',
    task_labels: 'task_lab',
    user_labels: 'user_lab'
  }

  up do
    transaction do
      collate_opts = {}
      dbtype = if self.class.name.match?(/mysql/i)
                 collate_opts[:collate] = :utf8_bin
                 'mysql'
               elsif self.class.name.match?(/postgres/i)
                 'postgres'
               else
                 raise 'unknown database'
               end

      # remove duplicates in label tables
      label_tables_to_migrate.each do |table, table_short|
        self[table].for_update.all
        dup_groups = self[table].
                     select(Sequel.function(:max, :id)).
                     group_by(:resource_guid, :key_prefix, :key_name).
                     having { count.function.* > 0 }

        self[table].exclude(id: dup_groups).each do |row|
          self[table].where(id: row[:id]).delete
        end
      end

      # remove duplicates in annotation tables
      annotaion_tables_to_migrate.each do |table, table_short|
        self[table].for_update.all
        dup_groups = self[table].
                     select(Sequel.function(:max, :id)).
                     group_by(:resource_guid, :key_prefix, :key).
                     having { count.function.* > 0 }

        self[table].exclude(id: dup_groups).each do |row|
          self[table].where(id: row[:id]).delete
        end
      end

      # add new column, hash, unique index and triggers for label tables
      label_tables_to_migrate.each do |table, table_short|
        prefix = table_short.to_s
        index = prefix + '_resource_guid_key_prefix_key_name_hash_idx'
        insert_trigger = prefix + '_add_unique_hash_insert_trigger'
        update_trigger = prefix + '_add_unique_hash_update_trigger'

        if dbtype == 'mysql'
          run <<-SQL
            ALTER TABLE #{table} ADD COLUMN resource_guid_key_prefix_key_name_hash varchar(70) NOT NULL DEFAULT '0';
          SQL
          run <<-SQL
            UPDATE #{table} SET resource_guid_key_prefix_key_name_hash=(SHA2(
                CONCAT(
                COALESCE(resource_guid, '' ) ,
                COALESCE(key_prefix , '')  ,
                COALESCE(key_name ,'')
                ),
                256));
          SQL
          run <<-SQL
            ALTER TABLE #{table} ADD UNIQUE INDEX #{index} (resource_guid_key_prefix_key_name_hash);
          SQL
          run <<-SQL
           CREATE TRIGGER #{insert_trigger} BEFORE INSERT ON #{table} FOR EACH ROW BEGIN
                                  SET NEW.`resource_guid_key_prefix_key_name_hash` = SHA2(
                    CONCAT(
                      COALESCE(NEW.`resource_guid`, '' ) ,
                      COALESCE(NEW.`key_prefix` , '')  ,
                      COALESCE(NEW.`key_name` ,'')
                    ),
                    256);
            END ;
          SQL
          run <<-SQL

           CREATE TRIGGER #{update_trigger} BEFORE UPDATE ON #{table} FOR EACH ROW BEGIN
                                  SET NEW.`resource_guid_key_prefix_key_name_hash` = SHA2(
                    CONCAT(
                      COALESCE(NEW.`resource_guid`, '' ) ,
                      COALESCE(NEW.`key_prefix` , '')  ,
                      COALESCE(NEW.`key_name` ,'')
                    ),
                    256);
            END ;

          SQL
        elsif dbtype == 'postgres'
          run <<-SQL
            ALTER TABLE #{table} DROP COLUMN IF EXISTS resource_guid_key_prefix_key_name_hash ;
            ALTER TABLE #{table} ADD COLUMN resource_guid_key_prefix_key_name_hash varchar(70) NOT NULL DEFAULT '0';
          SQL
          run <<-SQL
            UPDATE #{table} SET resource_guid_key_prefix_key_name_hash=(encode(digest(
              COALESCE("resource_guid", '' ) || COALESCE("key_prefix", '')  ||
              COALESCE("key_name", ''), 'sha256'), 'hex'));
          SQL
          run <<-SQL
            CREATE UNIQUE INDEX #{index} ON #{table} (resource_guid_key_prefix_key_name_hash);
          SQL
          run <<-SQL
            CREATE OR REPLACE FUNCTION labels_add_unique_hash()
              RETURNS TRIGGER
              LANGUAGE PLPGSQL
              AS
            $$
            BEGIN
              NEW."resource_guid_key_prefix_key_name_hash" = encode(digest(
              COALESCE(NEW."resource_guid", '' ) || COALESCE(NEW."key_prefix", '')  ||
              COALESCE(NEW."key_name", ''), 'sha256'), 'hex');

              RETURN NEW;
            END;
            $$;
          SQL
          run <<-SQL
            drop trigger if exists #{insert_trigger} on #{table};
            CREATE TRIGGER #{insert_trigger}
            BEFORE INSERT
            ON #{table}
            FOR EACH ROW
            EXECUTE PROCEDURE labels_add_unique_hash();
            END;
          SQL
          run <<-SQL
            CREATE OR REPLACE FUNCTION labels_add_unique_update_hash()
              RETURNS TRIGGER
              LANGUAGE PLPGSQL
              AS
            $$
            BEGIN
              NEW."resource_guid_key_prefix_key_name_hash" = encode(digest(
              COALESCE(NEW."resource_guid", '' ) || COALESCE(NEW."key_prefix", '')  ||
              COALESCE(NEW."key_name", ''), 'sha256'), 'hex');

              RETURN NEW;
            END;
            $$;
          SQL
          run <<-SQL
            drop trigger if exists #{update_trigger} on #{table};
            CREATE TRIGGER #{update_trigger}
            BEFORE UPDATE
            ON #{table}
            FOR EACH ROW
            EXECUTE PROCEDURE labels_add_unique_update_hash();
            END;
          SQL
        end
      end

      # add new column, hash, unique index and triggers for annotation tables
      annotaion_tables_to_migrate.each do |table, table_short|
        prefix = table_short.to_s
        index = prefix + '_resource_guid_key_prefix_key_hash_idx'
        insert_trigger = prefix + '_add_unique_hash_insert_trigger'
        update_trigger = prefix + '_add_unique_hash_update_trigger'

        if dbtype == 'mysql'
          run <<-SQL
            ALTER TABLE #{table} ADD COLUMN resource_guid_key_prefix_key_hash varchar(70) NOT NULL DEFAULT '0';
          SQL
          run <<-SQL
            UPDATE #{table} SET resource_guid_key_prefix_key_hash=(SHA2(
                CONCAT(
                COALESCE(resource_guid, '' ) ,
                COALESCE(key_prefix , '')  ,
                COALESCE(#{table}.key ,'')
                ),
                256));
          SQL
          run <<-SQL
            ALTER TABLE #{table} ADD UNIQUE INDEX #{index} (resource_guid_key_prefix_key_hash);
          SQL
          run <<-SQL
           CREATE TRIGGER #{insert_trigger} BEFORE INSERT ON #{table} FOR EACH ROW BEGIN
                                  SET NEW.`resource_guid_key_prefix_key_hash` = SHA2(
                    CONCAT(
                      COALESCE(NEW.`resource_guid`, '' ) ,
                      COALESCE(NEW.`key_prefix` , '')  ,
                      COALESCE(NEW.`key` ,'')
                    ),
                    256);
            END ;
          SQL
          run <<-SQL
           CREATE TRIGGER #{update_trigger} BEFORE UPDATE ON #{table} FOR EACH ROW BEGIN
                                  SET NEW.`resource_guid_key_prefix_key_hash` = SHA2(
                    CONCAT(
                      COALESCE(NEW.`resource_guid`, '' ) ,
                      COALESCE(NEW.`key_prefix` , '')  ,
                      COALESCE(NEW.`key` ,'')
                    ),
                    256);
            END;

          SQL
        elsif dbtype == 'postgres'
          run <<-SQL
            ALTER TABLE #{table} DROP COLUMN IF EXISTS resource_guid_key_prefix_key_hash ;
            ALTER TABLE #{table} ADD COLUMN resource_guid_key_prefix_key_hash varchar(70) NOT NULL DEFAULT '0';
          SQL
          run <<-SQL
            UPDATE #{table} SET resource_guid_key_prefix_key_hash=(encode(digest(
              COALESCE("resource_guid", '' ) || COALESCE("key_prefix", '')  ||
              COALESCE("key", ''), 'sha256'), 'hex'));
          SQL
          run <<-SQL
            CREATE UNIQUE INDEX #{index} ON #{table} (resource_guid_key_prefix_key_hash);
          SQL
          run <<-SQL
            CREATE OR REPLACE FUNCTION annotations_add_unique_hash()
              RETURNS TRIGGER
              LANGUAGE PLPGSQL
              AS
            $$
            BEGIN
              NEW."resource_guid_key_prefix_key_hash" = encode(digest(
              COALESCE(NEW."resource_guid", '' ) || COALESCE(NEW."key_prefix", '')  ||
              COALESCE(NEW."key", ''), 'sha256'), 'hex');

              RETURN NEW;
            END;
            $$;
          SQL
          run <<-SQL
            drop trigger if exists #{insert_trigger} on #{table};
            CREATE TRIGGER #{insert_trigger}
            BEFORE INSERT
            ON #{table}
            FOR EACH ROW
            EXECUTE PROCEDURE annotations_add_unique_hash();
            END;
          SQL
          run <<-SQL
            CREATE OR REPLACE FUNCTION annotations_add_unique_update_hash()
              RETURNS TRIGGER
              LANGUAGE PLPGSQL
              AS
            $$
            BEGIN
              NEW."resource_guid_key_prefix_key_hash" = encode(digest(
              COALESCE(NEW."resource_guid", '' ) || COALESCE(NEW."key_prefix", '')  ||
              COALESCE(NEW."key", ''), 'sha256'), 'hex');

              RETURN NEW;
            END;
            $$;
          SQL
          run <<-SQL
            drop trigger if exists #{update_trigger} on #{table};
            CREATE TRIGGER #{update_trigger}
            BEFORE UPDATE
            ON #{table}
            FOR EACH ROW
            EXECUTE PROCEDURE annotations_add_unique_update_hash();
            END;
          SQL
        end
      end
    end
  end

  down do
    label_tables_to_migrate.each do |table, table_short|
      self[table].filter(key_prefix: '').all.each do |t|
        t.update(key_prefix: nil)
      end
      self[table].filter(key_name: '').all.each do |t|
        t.update(key: nil)
      end
      self[table].filter(resource_guid: '').all.each do |t|
        t.update(resource_guid: nil)
      end
      prefix = table_short.to_s
      index = prefix + '_resource_guid_key_prefix_key_name_hash_idx'
      insert_trigger = prefix + '_add_unique_hash_insert_trigger'
      update_trigger = prefix + '_add_unique_hash_update_trigger'
      alter_table table do
        drop_index [:resource_guid_key_prefix_key_name_hash], name: index, type: :unique
        drop_column [:resource_guid_key_prefix_key_name_hash]
        drop_trigger [:resource_guid_key_prefix_key_name_hash], name: insert_trigger
        drop_trigger [:resource_guid_key_prefix_key_name_hash], name: update_trigger
      end
    end
    annotaion_tables_to_migrate.each do |table, table_short|
      self[table].filter(key_prefix: '').all.each do |t|
        t.update(key_prefix: nil)
      end
      self[table].filter(key: '').all.each do |t|
        t.update(key: nil)
      end
      self[table].filter(resource_guid: '').all.each do |t|
        t.update(resource_guid: nil)
      end
      prefix = table_short.to_s
      index = prefix + '_resource_guid_key_prefix_key_hash_idx'
      insert_trigger = prefix + '_add_unique_hash_insert_trigger'
      update_trigger = prefix + '_add_unique_hash_update_trigger'
      alter_table table do
        drop_index [:resource_guid_key_prefix_key_hash], name: index, type: :unique
        drop_column [:resource_guid_key_prefix_key_hash]
        drop_trigger [:resource_guid_key_prefix_key_hash], name: insert_trigger
        drop_trigger [:resource_guid_key_prefix_key_hash], name: update_trigger
      end
    end
  end
end
