
module VCAP::CloudController
  class ServiceInstanceOperation < Sequel::Model
    export_attributes :type, :state, :description, :updated_at
    import_attributes :type, :state, :description
  end
end
