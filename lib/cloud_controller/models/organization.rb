# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    one_to_many       :spaces

    one_to_many       :domains

    define_user_group :users
    define_user_group :managers, :reciprocol => :managed_organizations
    define_user_group :billing_managers,
                      :reciprocol => :billing_managed_organizations
    define_user_group :auditors,
                      :reciprocol => :audited_organizations

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name
    import_attributes :name, :user_guids, :manager_guids, :billing_manager_guids, :auditor_guids

    def validate
      validates_presence :name
      validates_unique   :name
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override({
        :managers => [user],
        :users => [user],
        :billing_managers => [user],
        :auditors => [user] }.sql_or)
    end
  end
end
