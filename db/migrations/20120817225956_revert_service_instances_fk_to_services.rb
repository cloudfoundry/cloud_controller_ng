# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    drop_column :service_instances, :service_id
  end
end
