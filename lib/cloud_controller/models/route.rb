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
  end
end
