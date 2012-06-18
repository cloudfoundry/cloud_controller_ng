# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    no_auto_guid

    many_to_many      :organizations

    many_to_many      :managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_managers",
                      :right_key => :organization_id, :reciprocal => :managers

    many_to_many      :billing_managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_billing_managers",
                      :right_key => :organization_id,
                      :reciprocal => :billing_managers

    many_to_many      :audited_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_auditors",
                      :right_key => :organization_id, :reciprocal => :auditors

    many_to_many      :app_spaces

    default_order_by  :id

    export_attributes :admin, :active

    import_attributes :guid, :admin, :active,
                      :organization_guids,
                      :managed_organization_guids,
                      :billing_managed_organization_guids,
                      :audited_organization_guids,
                      :app_space_guids

    def validate
      validates_presence :guid
      validates_unique   :guid
    end

    def admin?
      admin
    end

    def active?
      active
    end
  end
end
