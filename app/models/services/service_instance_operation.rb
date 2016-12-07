module VCAP::CloudController
  class ServiceInstanceOperation < Sequel::Model
    plugin :serialization

    export_attributes :type, :state, :description, :updated_at, :created_at
    import_attributes :state, :description

    serialize_attributes :json, :proposed_changes

    def validate
      validates_max_length 10_000, :broker_provided_operation if broker_provided_operation
    end

    def proposed_changes
      super || {}
    end

    def update_attributes(attrs)
      self.set_all attrs
      self.save
    end
  end
end
