# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :apps do
      add_column :detected_buildpack, String
    end
  end
end
