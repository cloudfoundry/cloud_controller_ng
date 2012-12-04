# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :quota_definitions do
      VCAP::Migration.common(self)

      String :name, :null => false, :index => true, :unique => true, :case_insensitive => true
      Boolean :non_basic_services_allowed, :null => false
      Integer :total_services, :null => false
    end
  end
end
