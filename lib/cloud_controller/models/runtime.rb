# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Runtime < Sequel::Model
    one_to_many :apps

    default_order_by  :name
    export_attributes :id, :name, :description, :created_at, :updated_at
    import_attributes :name, :description

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_unique   :name
    end
  end
end
