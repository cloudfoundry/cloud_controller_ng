# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class App < Sequel::Model
    many_to_one       :app_space
    many_to_one       :framework
    many_to_one       :runtime
    one_to_many       :service_bindings

    default_order_by  :name

    export_attributes :name, :app_space_guid, :framework_guid, :runtime_guid,
                      :environment_json, :memory, :instances, :file_descriptors,
                      :disk_quota, :state

    import_attributes :name, :app_space_guid, :framework_guid, :runtime_guid,
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
      validate_environment
    end

    def environment_json=(val)
      val = Yajl::Encoder.encode(val)
      super(val)
    end

    def validate_environment
      return if environment_json.nil?
      h = Yajl::Parser.parse(environment_json)
      errors.add(:environment_json, :invalid_json) unless h.kind_of?(Hash)
      h.keys.each do |k|
        errors.add(:environment_json, "reserved_key:#{k}") if k =~ /^(vcap|vmc)_/i
      end
    rescue Yajl::ParseError
      errors.add(:environment_json, :invalid_json)
    end

  end
end
