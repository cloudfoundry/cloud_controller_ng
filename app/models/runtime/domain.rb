module VCAP::CloudController
  class Domain < Sequel::Model
    class UnauthorizedAccessToPrivateDomain < RuntimeError; end

    DOMAIN_REGEX = /^(([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])\.)+([a-z0-9]|[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])$/ix.freeze

    dataset.row_proc = proc do |row|
      if row[:owning_organization_id]
        PrivateDomain.call(row)
      else
        SharedDomain.call(row)
      end
    end

    SHARED_DOMAIN_CONDITION =  { owning_organization_id: nil }.freeze

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
      before_set: :validate_add_shared_organization
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

      validates_format DOMAIN_REGEX, :name
      validates_length_range 3..255, :name

      errors.add(:name, :overlapping_domain) if name_overlaps?
      errors.add(:name, :route_conflict) if routes_match?
    end

    def name_overlaps?
      return true unless intermediate_domains.drop(1).all? do |suffix|
        d = Domain.find(name: suffix)
        d.nil? || d.owning_organization == owning_organization || d.shared?
      end

      false
    end

    def routes_match?
      return false unless name && name =~ DOMAIN_REGEX

      if name.include?('.')
        route_host = name[0, name.index('.')]
        route_domain_name = name[name.index('.') + 1, name.length]
        route_domain = Domain.find(name: route_domain_name)
        return false if route_domain.nil?
        return true if Route.dataset.filter(host: route_host, domain: route_domain).count > 0
      end
      false
    end

    def self.intermediate_domains(name)
      return [] unless name && name =~ DOMAIN_REGEX

      name.split('.').reverse.inject([]) do |a, e|
        a.push(a.empty? ? e : "#{e}.#{a.last}")
      end
    end

    def self.user_visibility_filter(user)
      organizations_filter = dataset.db[:organizations_managers].where(user_id: user.id).select(:organization_id).union(
        dataset.db[:organizations_auditors].where(user_id: user.id).select(:organization_id)
      ).union(
        Space.dataset.join_table(:inner, :spaces_developers, space_id: :spaces__id, user_id: user.id).select(:organization_id)
      ).union(
        Space.dataset.join_table(:inner, :spaces_auditors, space_id: :spaces__id, user_id: user.id).select(:organization_id)
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
      raise VCAP::Errors::ApiError.new_from_details('DomainInvalid', 'the owning organization cannot be changed')
    end

    def intermediate_domains
      self.class.intermediate_domains(name)
    end

    def validate_add_shared_organization(organization)
      !shared? && !owned_by(organization)
    end
  end
end
