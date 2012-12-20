# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    rename_table :quota_definitions, :service_instances_quota_definitions
  end
end
