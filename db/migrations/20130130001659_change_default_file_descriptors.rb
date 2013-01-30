# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    alter_table :apps do
      set_column_default :file_descriptors, 16_384
    end
  end
end
