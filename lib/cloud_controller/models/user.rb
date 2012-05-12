# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    unrestrict_primary_key

    many_to_many      :organizations
    many_to_many      :app_spaces

    default_order_by  :id

    export_attributes :id, :admin, :active

    import_attributes :id, :admin, :active,
                      :organization_ids, :app_space_ids

    def validate
      validates_presence :id
      validates_unique :id
    end

    def admin?
      admin
    end

    def active?
      active
    end
  end
end
