# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Route < Sequel::Model
    many_to_one :domain

    many_to_many :apps
    add_association_dependencies :apps => :nullify

    export_attributes :host, :domain_guid
    import_attributes :host, :domain_guid
    strip_attributes  :host

    # TODO: add this sort of functionality to vcap validations
    # i.e. a strip_down_attributes sort of thing
    def host=(val)
      val = val.downcase
      super(val)
    end

    def organization
      domain.organization
    end

    # The route is on the same spaces as the domain.  We expose this so that
    # app space level permssions can be applied to the route.  This, and the
    # spaces_dataset method can probably be done via a fancy many_to_many, but
    # it wasn't immediately clear how to do this, and this works.
    def spaces
      domain.spaces
    end

    def spaces_dataset
      domain.spaces_dataset
    end

    def fqdn
      "#{host}.#{domain.name}"
    end

    def validate
      validates_presence :host
      validates_presence :domain
      # TODO: not accurate regex
      validates_format   /^([\w\-]+)$/, :host
      validates_unique   [:host, :domain_id]
    end

    def self.user_visibility_filter(user)
      visible_domains = Domain.filter(Domain.user_visibility_filter(user))
      user_visibility_filter_with_admin_override(:domain => visible_domains)
    end
  end
end
