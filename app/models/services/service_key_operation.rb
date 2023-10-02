module VCAP::CloudController
  class ServiceKeyOperation < Sequel::Model
    export_attributes :state, :description, :type, :updated_at, :created_at

    def update_attributes(attrs)
      set attrs
      save
    end
  end
end
