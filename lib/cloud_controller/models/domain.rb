# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Domain < Sequel::Model
    class InvalidRelation         < StandardError; end
    class InvalidSpaceRelation < InvalidRelation; end

    many_to_one       :organization
    one_to_many       :routes

    default_order_by  :name

    export_attributes :name, :organization_guid
    import_attributes :name, :organization_guid
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

    def validate_space(space)
      unless space && organization && organization.spaces.include?(space)
        raise InvalidSpaceRelation.new(space.guid)
      end
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
        :organization => orgs,
        :spaces => spaces
      }.sql_or)
    end
  end
end
