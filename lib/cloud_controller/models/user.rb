# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class User < Sequel::Model
    no_auto_guid

    many_to_many      :organizations

    many_to_one       :default_app_space, :key => :default_app_space_id,
                      :class => "VCAP::CloudController::Models::AppSpace"

    many_to_many      :managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_managers",
                      :right_key => :organization_id, :reciprocol => :managers

    many_to_many      :billing_managed_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_billing_managers",
                      :right_key => :organization_id,
                      :reciprocol => :billing_managers

    many_to_many      :audited_organizations,
                      :class => "VCAP::CloudController::Models::Organization",
                      :join_table => "organizations_auditors",
                      :right_key => :organization_id, :reciprocol => :auditors

    many_to_many      :app_spaces,
                      :class => "VCAP::CloudController::Models::AppSpace",
                      :join_table => "app_spaces_developers",
                      :right_key => :app_space_id, :reciprocol => :developers

    many_to_many      :managed_app_spaces,
                      :class => "VCAP::CloudController::Models::AppSpace",
                      :join_table => "app_spaces_managers",
                      :right_key => :app_space_id, :reciprocol => :managers

    many_to_many      :audited_app_spaces,
                      :class => "VCAP::CloudController::Models::AppSpace",
                      :join_table => "app_spaces_auditors",
                      :right_key => :app_space_id, :reciprocol => :auditors

    add_association_dependencies :organizations => :nullify
    add_association_dependencies :managed_organizations => :nullify
    add_association_dependencies :audited_app_spaces => :nullify
    add_association_dependencies :billing_managed_organizations => :nullify
    add_association_dependencies :audited_organizations => :nullify
    add_association_dependencies :app_spaces => :nullify
    add_association_dependencies :managed_app_spaces => :nullify

    default_order_by  :id

    export_attributes :admin, :active, :default_app_space_guid

    import_attributes :guid, :admin, :active,
                      :organization_guids,
                      :managed_organization_guids,
                      :billing_managed_organization_guids,
                      :audited_organization_guids,
                      :app_space_guids,
                      :default_app_space_guid

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
