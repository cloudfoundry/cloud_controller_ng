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

    SHARED_DOMAIN_CONDITION =  {owning_organization_id: nil}

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
                class: "VCAP::CloudController::Space",
                dataset: -> { raise "Must be used for eager loading" },
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

    many_to_one :owning_organization, class: "VCAP::CloudController::Organization",
                  :before_set => :validate_change_owning_organization
    one_to_many :routes

    add_association_dependencies routes: :destroy

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes  :name

    def validate
      validates_presence :name
      validates_unique   :name

      validates_format DOMAIN_REGEX, :name
      validates_length_range 3..255, :name

      errors.add(:name, :overlapping_domain) if overlaps_domain_in_other_org?
      errors.add(:name, :overlapping_domain) if overlaps_with_shared_domains?
    end

    def overlaps_domain_in_other_org?
      domains_to_check = intermediate_domains
      return unless domains_to_check

      overlapping_domains = Domain.dataset.filter(
        :name => domains_to_check
      ).exclude(:id => id)

      if owning_organization
        overlapping_domains = overlapping_domains.exclude(
          :owning_organization => owning_organization
        )
      end

      overlapping_domains.count != 0
    end
    
    def overlaps_with_shared_domains?
      if owning_organization
        return true if Domain.dataset.filter(
          Sequel.like(:name,"%.#{name}"),
          owning_organization_id: nil
        ).count > 0
      end
    end

    def self.intermediate_domains(name)
      return unless name and name =~ DOMAIN_REGEX

      name.split(".").reverse.inject([]) do |a, e|
        a.push(a.empty? ? e : "#{e}.#{a.last}")
      end
    end

    def self.user_visibility_filter(user)
      allowed_organizations = Organization.filter(Sequel.or(
                                     managers: [user],
                                     auditors: [user],
                                     spaces: Space.having_developers(user)))

      Sequel.or(
        SHARED_DOMAIN_CONDITION.merge(owning_organization: allowed_organizations)
      )
    end

    def usable_by_organization?(org)
      shared? || owned_by?(org)
    end

    def shared?
      owning_organization_id.nil?
    end

    def in_suspended_org?
      return owning_organization.suspended? if owning_organization
      false
    end

    private

    def validate_change_owning_organization(organization)
      return if owning_organization.nil?
      return if organization.id == owning_organization.id
      raise VCAP::Errors::ApiError.new_from_details("AssociationNotEmpty", "routes", "Domain") unless routes.empty?
    end

    def intermediate_domains
      self.class.intermediate_domains(name)
    end
  end
end
