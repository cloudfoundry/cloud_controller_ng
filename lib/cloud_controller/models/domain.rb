# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Domain < Sequel::Model
    class InvalidRelation < StandardError; end
    class InvalidSpaceRelation < InvalidRelation; end
    class InvalidOrganizationRelation < InvalidRelation; end

    many_to_one       :owning_organization,
                      :class => "VCAP::CloudController::Models::Organization"

    many_to_many      :organizations, :before_add => :validate_organization
    add_association_dependencies :organizations => :nullify

    one_to_many       :routes

    default_order_by  :name

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes  :name

    many_to_many      :spaces, :before_add => :validate_space
    add_association_dependencies :spaces => :nullify

    # TODO: add this sort of functionality to vcap validations
    # i.e. a strip_down_attributes sort of thing
    def name=(val)
      val = val.downcase
      super(val)
    end

    def validate
      validates_presence :name
      validates_unique   :name

      if new? || column_changed?(:owning_organization)
        unless VCAP::CloudController::SecurityContext.current_user_is_admin?
          validates_presence :owning_organization
        end
      end

      # TODO: this is:
      #
      # a) temporary.  we don't want to limit ourselves to
      # two level domains only.
      #
      # b) not accurate.  this is not an accurate regex for a fqdn
      validates_format  /^[\w\-]+\.[\w\-]+$/, :name
    end

    def validate_space(space)
      unless space && owning_organization && owning_organization.spaces.include?(space)
        raise InvalidSpaceRelation.new(space.guid)
      end
    end

    def validate_organization(org)
      return unless owning_organization
      unless org && owning_organization.id == org.id
        raise InvalidOrganizationRelation.new(org.guid)
      end
    end

    # For permission checks
    def organization
      owning_organization
    end

    def self.user_visibility_filter(user)
      orgs = Organization.filter({
        :managers => [user],
        :auditors => [user]
      }.sql_or)

      spaces = Space.filter({
        :developers => [user],
        :managers => [user],
        :auditors => [user]
      }.sql_or)

      user_visibility_filter_with_admin_override({
        :owning_organization => orgs,
        :spaces => spaces
      }.sql_or)
    end
  end
end
