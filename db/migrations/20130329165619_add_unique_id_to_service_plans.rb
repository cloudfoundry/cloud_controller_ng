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
      set_column_allow_null :unique_id, false
    end
  end
end
