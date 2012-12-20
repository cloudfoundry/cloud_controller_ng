# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :memory_quota_definitions do
      VCAP::Migration.common(self)

      String :name, :null => false, :index => true, :unique => true, :case_insensitive => true
      Integer :free_limit, :null => false
      Integer :paid_limit, :null => false
    end
  end
end
