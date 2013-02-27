# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Stack < Sequel::Model
    plugin :serialization

    export_attributes :name, :description
    import_attributes :name, :description

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :description
      validates_unique   :name
    end
  end
end
