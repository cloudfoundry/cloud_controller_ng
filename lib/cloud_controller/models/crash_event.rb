# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class CrashEvent < Sequel::Model

    def_column_alias :timestamp, :event_timestamp
    
    many_to_one :app

    export_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp
    import_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description, :timestamp

    def validate
      validates_presence :app
      validates_presence :instance_guid
      validates_presence :instance_index
      validates_presence :exit_status
      validates_presence :timestamp
    end
  end
end
