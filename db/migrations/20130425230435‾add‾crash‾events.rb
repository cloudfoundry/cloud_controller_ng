# Copyright (c) 2009-2012 VMware, Inc.

Sequel.migration do
  change do
    create_table :crash_events do
      VCAP::Migration.common(self)

      Integer :app_id, null: false
      String :instance_guid, null: false
      Integer :instance_index, null: false
      Integer :exit_status, null: false
      DateTime :timestamp, null: false
      String :exit_description

      index :app_id

      foreign_key [:app_id], :apps, name: :fk_crash_events_app_id
    end
  end
end
