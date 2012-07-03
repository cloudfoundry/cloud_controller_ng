# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Domain < Sequel::Model
    class InvalidRelation         < StandardError; end
    class InvalidAppSpaceRelation < InvalidRelation; end

    many_to_one       :organization
    one_to_many       :routes

    default_order_by  :name

    export_attributes :name, :organization_guid
    import_attributes :name, :organization_guid
    strip_attributes  :name

    many_to_many      :app_spaces, :before_add => :validate_app_space
    add_association_dependencies :app_spaces => :nullify

    # TODO: add this sort of functionality to vcap validations
    # i.e. a strip_down_attributes sort of thing
    def name=(val)
      val = val.downcase
      super(val)
    end

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique   :name

      # TODO: this is:
      #
      # a) temporary.  we don't want to limit ourselves to
      # two level domains only.
      #
      # b) not accurate.  this is not an accurate regex for a fqdn
      validates_format  /^[\w\-]+\.[\w\-]+$/, :name
    end

    def validate_app_space(app_space)
      unless app_space && organization && organization.app_spaces.include?(app_space)
        raise InvalidAppSpaceRelation.new(app_space.guid)
      end
    end

    def self.user_visibility_filter(user)
      managed_orgs = user.managed_organizations_dataset
      user_visibility_filter_with_admin_override(:organization => managed_orgs)
    end
  end
end
