# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    unrestrict_primary_key

    many_to_many      :organizations

    many_to_many      :managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_managers",
                      :right_key => :organization_id, :reciprocol => :managers

    many_to_many      :billing_managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_billing_managers",
                      :right_key => :organization_id, :reciprocol => :billing_managers

    many_to_many      :app_spaces

    default_order_by  :id

    export_attributes :id, :admin, :active

    import_attributes :id, :admin, :active,
                      :organization_ids,
                      :managed_organization_ids,
                      :billing_managed_organization_ids,
                      :app_space_ids

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

    def guid
      id
    end
  end
end
