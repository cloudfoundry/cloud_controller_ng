# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class App < Sequel::Model
    many_to_one       :app_space
    many_to_one       :framework
    many_to_one       :runtime
    one_to_many       :service_bindings

    default_order_by  :name

    export_attributes :id, :name, :app_space_id, :framework_id, :runtime_id,
                      :service_binding_ids, :environment_json, :memory,
                      :instances, :file_descriptors, :disk_quota,
                      :state, :created_at, :updated_at

    import_attributes :name, :app_space_id, :framework_id, :runtime_id,
                      :environment_json, :memory, :instances,
                      :file_descriptors, :disk_quota, :state

    strip_attributes  :name

    def validate
      # TODO: if we move the defaults out of the migration and up to the
      # controller (as it probably should be), do more presence validation
      # here
      validates_presence :name
      validates_presence :app_space
      validates_presence :framework
      validates_presence :runtime
      validates_unique   [:app_space_id, :name]
    end
  end
end
