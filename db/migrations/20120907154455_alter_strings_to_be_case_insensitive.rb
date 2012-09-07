# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    # postrges would probably have preserved the index/unique settings, but
    # sqlite doesn't, so they need to be respecified during the alter.

    alter_table :organizations do
      set_column_type :name, String, :index => true, :unique => true, :case_insensitive => true
    end

    alter_table :domains do
      set_column_type :name, String, :index => true, :unique => true, :case_insensitive => true
    end

    alter_table :spaces do
      set_column_type :name, String, :case_insensitive => true
    end

    alter_table :service_auth_tokens do
      set_column_type :label, String, :case_insensitive => true
      set_column_type :provider, String, :case_insensitive => true
    end

    alter_table :services do
      set_column_type :label, String, :case_insensitive => true
      set_column_type :provider, String, :case_insensitive => true
    end

    alter_table :service_plans do
      set_column_type :name, String, :case_insensitive => true
    end

    alter_table :service_instances do
      set_column_type :name, String, :case_insensitive => true
    end

    alter_table :runtimes do
      set_column_type :name, String, :case_insensitive => true
    end

    alter_table :frameworks do
      set_column_type :name, String, :case_insensitive => true
    end

    alter_table :routes do
      set_column_type :host, String, :case_insensitive => true
    end

    alter_table :apps do
      set_column_type :name, String, :case_insensitive => true
    end
  end
end
