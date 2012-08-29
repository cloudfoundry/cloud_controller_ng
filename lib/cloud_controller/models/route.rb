# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Route < Sequel::Model
    many_to_one :domain
    many_to_one :organization

    many_to_many :apps
    add_association_dependencies :apps => :nullify

    export_attributes :host, :domain_guid, :organization_guid
    import_attributes :host, :domain_guid, :organization_guid
    strip_attributes  :host

    # TODO: add this sort of functionality to vcap validations
    # i.e. a strip_down_attributes sort of thing
    def host=(val)
      val = val.downcase
      super(val)
    end

    def spaces
      organization.spaces
    end

    def spaces_dataset
      organization.spaces_dataset
    end

    def fqdn
      "#{host}.#{domain.name}"
    end

    def validate
      validates_presence :host
      validates_presence :domain
      validates_presence :organization
      # TODO: not accurate regex
      validates_format   /^([\w\-]+)$/, :host
      validates_unique   [:host, :domain_id]
    end

    def self.user_visibility_filter(user)
      spaces = Space.filter({
        :developers => [user],
        :auditors => [user],
        :managers => [user]
      }.sql_or)

      orgs = Organization.filter({
        :managers => [user],
        :auditors => [user],
        :spaces => spaces
      }.sql_or)

      user_visibility_filter_with_admin_override(:organization => orgs)
    end
  end
end
