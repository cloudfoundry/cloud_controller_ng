# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :service_plans do
      add_column :unique_id, String
      add_index :unique_id, unique: true
    end

    if self.class.name =~ /mysql/i
      run <<-SQL
        UPDATE service_plans
          SET unique_id =
          (SELECT CONCAT(services.provider, '_', services.label, '_', service_plans.name)
           FROM services
           WHERE services.id = service_plans.service_id)
      SQL
    elsif Sequel::Model.db.database_type == :mssql
      run <<-SQL
      UPDATE SERVICE_PLANS
        SET UNIQUE_ID =
        (SELECT CONCAT(SERVICES.PROVIDER, '_', SERVICES.LABEL, '_', SERVICE_PLANS.NAME)
          FROM SERVICES
          WHERE SERVICES.ID = SERVICE_PLANS.SERVICE_ID)
      SQL
    else
      run <<-SQL
        UPDATE service_plans
          SET unique_id =
          (SELECT (services.provider ||  '_' || services.label || '_' || service_plans.name)
           FROM services
           WHERE services.id = service_plans.service_id)
      SQL
    end

    alter_table :service_plans do
      drop_index :unique_id
      set_column_allow_null :unique_id, false
      add_index :unique_id, unique: true
    end
  end
end
