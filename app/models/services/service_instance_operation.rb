module VCAP::CloudController
  class ServiceInstanceOperation < Sequel::Model
    plugin :serialization

    export_attributes :type, :state, :description, :updated_at
    import_attributes :type, :state, :description

    serialize_attributes :json, :proposed_changes

    def proposed_changes
      super || {}
    end
  end
end
