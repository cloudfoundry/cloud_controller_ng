# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    no_auto_guid

    many_to_many      :organizations

    many_to_one       :default_space, :key => :default_space_id,
                      :class => "VCAP::CloudController::Models::Space"

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

    many_to_many      :spaces,
                      :class => "VCAP::CloudController::Models::Space",
                      :join_table => "spaces_developers",
                      :right_key => :space_id, :reciprocal => :developers

    many_to_many      :managed_spaces,
                      :class => "VCAP::CloudController::Models::Space",
                      :join_table => "spaces_managers",
                      :right_key => :space_id, :reciprocal => :managers

    many_to_many      :audited_spaces,
                      :class => "VCAP::CloudController::Models::Space",
                      :join_table => "spaces_auditors",
                      :right_key => :space_id, :reciprocal => :auditors

    add_association_dependencies :organizations => :nullify
    add_association_dependencies :managed_organizations => :nullify
    add_association_dependencies :audited_spaces => :nullify
    add_association_dependencies :billing_managed_organizations => :nullify
    add_association_dependencies :audited_organizations => :nullify
    add_association_dependencies :spaces => :nullify
    add_association_dependencies :managed_spaces => :nullify

    default_order_by  :id

    export_attributes :admin, :active, :default_space_guid

    import_attributes :guid, :admin, :active,
                      :organization_guids,
                      :managed_organization_guids,
                      :billing_managed_organization_guids,
                      :audited_organization_guids,
                      :space_guids,
                      :default_space_guid

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
