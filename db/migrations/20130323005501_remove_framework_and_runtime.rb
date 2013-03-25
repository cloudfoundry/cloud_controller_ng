# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :apps do
      drop_column :framework_id
      drop_column :runtime_id
    end

    drop_table :frameworks
    drop_table :runtimes
  end
end
