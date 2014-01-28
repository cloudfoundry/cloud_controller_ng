module VCAP::CloudController
  class Domain < Sequel::Model
    DOMAIN_REGEX = /^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}$/ix.freeze

    dataset.row_proc = proc do |row|
      if row[:owning_organization_id]
        PrivateDomain.call(row)
      else
        SharedDomain.call(row)
      end
    end

    dataset_module do
      def shared_domains
        filter(owning_organization_id: nil)
      end

      def private_domains
        filter(Sequel.~(owning_organization_id: nil))
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

    many_to_one :owning_organization, class: "VCAP::CloudController::Organization"
    one_to_many :routes

    add_association_dependencies routes: :destroy

    export_attributes :name, :owning_organization_guid
    import_attributes :name, :owning_organization_guid
    strip_attributes  :name

    def validate
      validates_presence :name
      validates_unique   :name

      validates_format DOMAIN_REGEX, :name

      errors.add(:name, :overlapping_domain) if overlaps_domain_in_other_org?
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

    def self.intermediate_domains(name)
      return unless name and name =~ DOMAIN_REGEX

      name.split(".").reverse.inject([]) do |a, e|
        a.push(a.empty? ? e : "#{e}.#{a.last}")
      end
    end

    def self.user_visibility_filter(user)
      orgs = Organization.filter(Sequel.or(
        managers: [user],
        auditors: [user],
      ))

      Sequel.or(
        owning_organization: orgs,
        owning_organization_id: nil,
      )
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

    private

    def intermediate_domains
      self.class.intermediate_domains(name)
    end
  end
end
