require "models/runtime/domain"

module VCAP::CloudController
  class PrivateDomain < Domain
    set_dataset(private_domains)

    default_order_by  :name

    add_association_dependencies routes: :destroy

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes  :name

    def as_summary_json
      {
        guid: guid,
        name: name,
        owning_organization_guid: owning_organization.guid,
      }
    end

    def validate
      super
      validates_presence :owning_organization
    end
  end
end
