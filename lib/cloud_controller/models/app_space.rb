# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class AppSpace < Sequel::Model
    class InvalidUserRelation < StandardError; end

    many_to_one       :organization
    many_to_many      :users, :before_add => :validate_user
    one_to_many       :apps
    one_to_many       :service_instances

    default_order_by  :name

    export_attributes :name, :organization_id

    import_attributes :name, :organization_id, :user_ids

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique   [:organization_id, :name]
    end

    def validate_user(user)
      unless organization && organization.users.include?(user)
        # TODO: unlike most other validations, this is *NOT* being enforced by
        # the db
        raise InvalidUserRelation.new(user.id)
      end
    end
  end
end
