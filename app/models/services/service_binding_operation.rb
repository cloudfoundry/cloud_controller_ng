module VCAP::CloudController
  class ServiceBindingOperation < Sequel::Model
    export_attributes :state, :description, :type, :updated_at, :created_at

    def update_attributes(attrs)
      self.set attrs
      self.save_changes
    end
  end
end
