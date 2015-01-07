# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :services do
      add_column :extra, String, text: true
    end
  end
end
