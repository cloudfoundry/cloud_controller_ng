# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    many_to_many      :users
    one_to_many       :app_spaces

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name
    import_attributes :name, :user_ids

    def validate
      validates_presence :name
      validates_unique   :name
    end
  end
end
