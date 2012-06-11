# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class Domain < Sequel::Model
    many_to_one       :organization

    default_order_by  :name

    export_attributes :name, :organization_guid
    import_attributes :name, :organization_guid
    strip_attributes  :name

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
  end
end
