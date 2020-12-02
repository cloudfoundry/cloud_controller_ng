module VCAP::CloudController
  class ServiceKeyOperation < Sequel::Model
    export_attributes :state, :description, :type, :updated_at, :created_at

    def update_attributes(attrs)
      self.set attrs
      self.save
    end
  end
end
