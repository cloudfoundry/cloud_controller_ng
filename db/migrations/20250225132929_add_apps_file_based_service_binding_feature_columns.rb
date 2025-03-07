Sequel.migration do
  up do
    if database_type == :postgres
      alter_table :apps do
        add_column :service_binding_k8s_enabled, :boolean, default: false, null: false, if_not_exists: true
        add_column :file_based_vcap_services_enabled, :boolean, default: false, null: false, if_not_exists: true

        unless check_constraint_exists?(@db)
          add_constraint(name: :only_one_sb_feature_enabled, if_not_exists: true) do
            Sequel.lit('NOT (service_binding_k8s_enabled AND file_based_vcap_services_enabled)')
          end
        end
      end

    elsif database_type == :mysql
      add_column :apps, :service_binding_k8s_enabled, :boolean, default: false, null: false unless schema(:apps).map(&:first).include?(:service_binding_k8s_enabled)
      add_column :apps, :file_based_vcap_services_enabled, :boolean, default: false, null: false unless schema(:apps).map(&:first).include?(:file_based_vcap_services_enabled)

      if check_constraint_supported?(self) && !check_constraint_exists?(self)
        run('ALTER TABLE apps ADD CONSTRAINT only_one_sb_feature_enabled CHECK (NOT (service_binding_k8s_enabled AND file_based_vcap_services_enabled))')
      end
    end
  end

  down do
    alter_table :apps do
      drop_constraint :only_one_sb_feature_enabled if check_constraint_supported?(@db) && check_constraint_exists?(@db)
      drop_column :service_binding_k8s_enabled if @db.schema(:apps).map(&:first).include?(:service_binding_k8s_enabled)
      drop_column :file_based_vcap_services_enabled if @db.schema(:apps).map(&:first).include?(:file_based_vcap_services_enabled)
    end
  end
end

def check_constraint_exists?(database)
  if database.database_type == :postgres
    database.check_constraints(:apps).include?(:only_one_sb_feature_enabled)
  elsif database.database_type == :mysql
    database[:information_schema__table_constraints].where(TABLE_SCHEMA: database.opts[:database], TABLE_NAME: 'apps', CONSTRAINT_TYPE: 'CHECK',
                                                           CONSTRAINT_NAME: 'only_one_sb_feature_enabled').any?
  end
end

# check constraints are not available in Mysql versions < 8
# this is also enforced on application level, so it should be fine not to create it on that version
def check_constraint_supported?(database)
  database.database_type == :postgres || (database.database_type == :mysql && database.server_version >= 80_000)
end
