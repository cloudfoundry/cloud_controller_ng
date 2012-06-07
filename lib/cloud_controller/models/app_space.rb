# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class AppSpace < Sequel::Model
    extend VCAP::CloudController::Models::UserGroup
    class InvalidDeveloperRelation < StandardError; end

    many_to_one       :organization

    define_user_group :developers, :reciprocol => :app_spaces,
                      :before_add => :validate_developer

    one_to_many       :apps
    one_to_many       :service_instances

    default_order_by  :name

    export_attributes :name, :organization_guid

    import_attributes :name, :organization_guid, :developer_guids

    strip_attributes  :name

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique   [:organization_id, :name]
    end

    def validate_developer(user)
      unless organization && organization.users.include?(user)
        # TODO: unlike most other validations, this is *NOT* being enforced by
        # the db
        raise InvalidDeveloperRelation.new(user.guid)
      end
    end
  end
end
