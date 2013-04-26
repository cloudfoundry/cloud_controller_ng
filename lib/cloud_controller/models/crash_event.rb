# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class CrashEvent < Sequel::Model

    many_to_one :app

    export_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description
    import_attributes :app_guid, :instance_guid, :instance_index, :exit_status, :exit_description

    def validate
      validates_presence :app
      validates_presence :instance_guid
      validates_presence :instance_index
      validates_presence :exit_status
    end
  end
end
