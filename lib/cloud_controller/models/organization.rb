# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Organization < Sequel::Model
    extend VCAP::CloudController::Models::UserGroup

    one_to_many       :app_spaces

    define_user_group :users
    define_user_group :managers, :reciprocol => :managed_organizations
    define_user_group :billing_managers,
                      :reciprocol => :billing_managed_organizations

    strip_attributes  :name

    default_order_by  :name

    export_attributes :name
    import_attributes :name, :user_ids, :manager_ids, :billing_manager_ids

    def validate
      validates_presence :name
      validates_unique   :name
    end
  end
end
