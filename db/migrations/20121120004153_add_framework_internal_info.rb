# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :frameworks do
      add_column :internal_info, String
    end
  end
end
