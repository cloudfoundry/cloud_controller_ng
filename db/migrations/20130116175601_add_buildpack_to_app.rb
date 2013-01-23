# Copyright (c) 2009-2013 VMware, Inc.

Sequel.migration do
  change do
    alter_table :apps do
      add_column :buildpack, String
    end
  end
end
