require 'cloud_controller/domain_decorator'

module VCAP::CloudController
  class Domain < Sequel::Model
    class UnauthorizedAccessToPrivateDomain < RuntimeError; end

    # The maximum fully-qualified domain length is 255 including separators, but this includes two "invisible"
    # characters at the beginning and end of the domain, so for string comparisons, the correct length is 253.
    #
    # The first character denotes the length of the first label, and the last character denotes the termination
    # of the domain.
    MAXIMUM_FQDN_DOMAIN_LENGTH = 253
    MAXIMUM_DOMAIN_LABEL_LENGTH = 63

    def self.call(row)
      return super unless equal?(Domain)
      if row[:owning_organization_id]
        PrivateDomain.call(row)
      else
        SharedDomain.call(row)
      end
    end

    SHARED_DOMAIN_CONDITION = { owning_organization_id: nil }.freeze

    dataset_module do
      def shared_domains
        filter(SHARED_DOMAIN_CONDITION)
      end

      def private_domains
        filter(Sequel.~(SHARED_DOMAIN_CONDITION))
      end

      def shared_or_owned_by(organization_ids)
        shared_domains.or(owning_organization_id: organization_ids)
      end
    end

    one_to_many :spaces_sti_eager_load,
                class: 'VCAP::CloudController::Space',
                dataset: -> { raise 'Must be used for eager loading' },
                eager_loader: proc { |eo|
                  id_map = {}
                  eo[:rows].each do |domain|
                    domain.associations[:spaces] = []
                    id_map[domain.owning_organization_id] = domain
                  end
                  ds = Space.filter(organization_id: id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]
                  ds.all do |space|
                    id_map[space.organization_id].associations[:spaces] << space
                  end
                }

    many_to_one(
      :owning_organization,
      class: 'VCAP::CloudController::Organization',
      before_set: :validate_change_owning_organization
    )
    one_to_many :routes
    many_to_many(
      :shared_organizations,
      class: 'VCAP::CloudController::Organization',
      join_table: 'organizations_private_domains',
      left_key: :private_domain_id,
      right_key: :organization_id,
      before_add: :validate_add_shared_organization
    )

    add_association_dependencies(
      routes: :destroy,
      shared_organizations: :nullify,
    )

    export_attributes :name, :owning_organization_guid, :shared_organizations
    import_attributes :name, :owning_organization_guid
    strip_attributes :name

    def validate
      validates_presence :name
      validates_unique :name, dataset: Domain.dataset

      validates_format CloudController::DomainDecorator::DOMAIN_REGEX, :name,
        message: 'can contain multiple subdomains, each having only alphanumeric characters and hyphens of up to 63 characters, see RFC 1035.'
      validates_length_range 3..MAXIMUM_FQDN_DOMAIN_LENGTH, :name, message: "must be no more than #{MAXIMUM_FQDN_DOMAIN_LENGTH} characters"

      errors.add(:name, :overlapping_domain) if name_overlaps?
      errors.add(:name, :route_conflict) if routes_match?
    end

    def self.user_visibility_filter(user)
      organizations_filter = dataset.db[:organizations_managers].where(user_id: user.id).select(:organization_id).union(
        dataset.db[:organizations_auditors].where(user_id: user.id).select(:organization_id)
      ).union(
        Space.dataset.join_table(:inner, :spaces_developers, space_id: :spaces__id, user_id: user.id).select(:organization_id)
      ).union(
        Space.dataset.join_table(:inner, :spaces_auditors, space_id: :spaces__id, user_id: user.id).select(:organization_id)
      ).union(
        Space.dataset.join_table(:inner, :spaces_managers, space_id: :spaces__id, user_id: user.id).select(:organization_id)
      ).select(:organization_id)

      shared_private_domains_filter = dataset.db[:organizations_private_domains].where(organization_id: organizations_filter).select(:private_domain_id)

      Sequel.or([
        SHARED_DOMAIN_CONDITION.flatten,
        [:owning_organization_id, organizations_filter],
        [:id, shared_private_domains_filter]
      ])
    end

    def usable_by_organization?(org)
      shared? || owned_by?(org)
    end

    def shared?
      owning_organization_id.nil?
    end

    def owned_by?(org)
      owning_organization_id == org.id
    end

    def in_suspended_org?
      return owning_organization.suspended? if owning_organization
      false
    end

    private

    def validate_change_owning_organization(organization)
      return if self.new? || owning_organization == organization
      raise CloudController::Errors::ApiError.new_from_details('DomainInvalid', 'the owning organization cannot be changed')
    end

    def validate_add_shared_organization(organization)
      organization.cancel_action if shared? || owned_by?(organization)
    end

    def name_overlaps?
      intermediate_domain_names = CloudController::DomainDecorator.new(name).intermediate_domains
      intermediate_domain_names.any? do |intermediate_domain|
        domain = Domain.find(name: intermediate_domain.name)
        domain && domain.owning_organization != owning_organization && !domain.shared?
      end
    end

    def routes_match?
      return false unless name

      domain = CloudController::DomainDecorator.new(name)
      domain.intermediate_domains.any? { |intermediate_domain| does_route_exist?(intermediate_domain) }
    end

    def does_route_exist?(domain)
      return false unless domain.valid_format?

      route_domain = Domain.find(name: domain.parent_domain.name)
      route_domain && matching_route(route_domain, domain.hostname)
    end

    def matching_route(route_domain, route_host)
      Route.dataset.filter(host: route_host, domain: route_domain).count > 0
    end
  end
end
