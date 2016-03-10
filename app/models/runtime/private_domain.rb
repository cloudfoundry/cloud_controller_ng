require 'models/runtime/domain'
require 'public_suffix'

module VCAP::CloudController
  class PrivateDomain < Domain
    set_dataset(private_domains)

    add_association_dependencies routes: :destroy

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes :name

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
      errors.add(:name, :reserved) if reserved?

      validates_presence :owning_organization
      exclude_domains_from_same_org = Domain.dataset.
                                      exclude(owning_organization_id: owning_organization_id).
                                      or(SHARED_DOMAIN_CONDITION)
      errors.add(:name, :overlapping_domain) if exclude_domains_from_same_org.filter(Sequel.like(:name, "%.#{name}")).count > 0

      validate_total_private_domains
    end

    def in_suspended_org?
      owning_organization.suspended?
    end

    def addable_to_organization!(org)
      unless owned_by?(org)
        raise UnauthorizedAccessToPrivateDomain
      end
    end

    def addable_to_organization?(org)
      !owned_by?(org)
    end

    def usable_by_organization?(org)
      owned_by?(org) || shared_by?(org)
    end

    def shared?
      false
    end

    class << self
      def configure(filename)
        list = nil
        if filename
          File.open(filename) do |f|
            list = PublicSuffix::List.parse(f)
          end
        else
          list = PublicSuffix::List.new
        end

        PublicSuffix::List.default = list
      end
    end

    private

    def shared_by?(org)
      shared_organization_ids.include?(org.id)
    end

    def validate_total_private_domains
      return unless new? && owning_organization

      private_domains_policy = MaxPrivateDomainsPolicy.new(owning_organization.quota_definition, owning_organization.owned_private_domains)
      unless private_domains_policy.allow_more_private_domains?(1)
        errors.add(:organization, :total_private_domains_exceeded)
      end
    end

    def reserved?
      rule = PublicSuffix::List.default.find(name)
      !rule.nil? && !rule.allow?(name)
    end
  end
end
