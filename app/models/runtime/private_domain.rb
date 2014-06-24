require "models/runtime/domain"

module VCAP::CloudController
  class PrivateDomain < Domain
    set_dataset(private_domains)

    add_association_dependencies routes: :destroy

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes  :name

    one_to_many :spaces,
                dataset: -> { owning_organization.spaces_dataset },
                eager_loader: proc { |eo|
                  id_map = {}
                  eo[:rows].each do |domain|
                    domain.associations[:spaces] = []
                    id_map[domain.owning_organization_id] ||= []
                    id_map[domain.owning_organization_id] << domain
                  end

                  ds = Space.filter(organization_id: id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]

                  ds.all do |space|
                    id_map[space.organization_id].each { |domain| domain.associations[:spaces] << space }
                  end
                }

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

    def in_suspended_org?
      owning_organization.suspended?
    end

    def addable_to_organization!(organization)
      unless owned_by?(organization)
        raise UnauthorizedAccessToPrivateDomain
      end
    end

    private
    def owned_by?(org)
      owning_organization_id == org.id
    end
  end
end
