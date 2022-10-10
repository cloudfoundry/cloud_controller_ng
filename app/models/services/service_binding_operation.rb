module VCAP::CloudController
  class ServiceBindingOperation < Sequel::Model
    export_attributes :state, :description, :type, :updated_at, :created_at
    many_to_one :service_binding
    def update_attributes(attrs)
      self.set attrs
      self.save
    end
  end
end
