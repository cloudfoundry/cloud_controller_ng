module VCAP::CloudController
  class ServiceBindingOperation < Sequel::Model
    # plugin :serialization
    #
    export_attributes :state, :description, :updated_at, :created_at
    # import_attributes :state, :description

    def update_attributes(attrs)
      self.set attrs
      self.save
    end
  end
end
