module VCAP::CloudController
  class Domain < Sequel::Model
    class InvalidSpaceRelation < InvalidRelation; end
    class InvalidOrganizationRelation < InvalidRelation; end

    DOMAIN_REGEX = /^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}$/ix.freeze

    many_to_one       :owning_organization, :class => "VCAP::CloudController::Organization"
    many_to_many      :organizations, :before_add => :validate_organization
    many_to_many      :spaces, :before_add => :validate_space
    one_to_many       :routes

    add_association_dependencies :organizations => :nullify, :spaces => :nullify,
      :routes => :destroy

    default_order_by  :name

    export_attributes :name, :owning_organization_guid, :wildcard
    import_attributes :name, :owning_organization_guid, :wildcard,
                      :space_guids
    strip_attributes  :name

    subset(:shared_domains) { {:owning_organization_id => nil} }

    def after_create
      add_organization owning_organization if owning_organization
      super
    end

    def validate
      validates_presence :name
      validates_unique   :name
      validates_presence :wildcard

      if !new? && column_changed?(:wildcard) && !wildcard && routes_dataset.filter(Sequel.~({:host => ""})).count > 0
        errors.add(:wildcard, :wildcard_routes_in_use)
      end

      if new? || column_changed?(:owning_organization)
        unless VCAP::CloudController::SecurityContext.admin?
          validates_presence :owning_organization
        end
      end

      validates_format DOMAIN_REGEX, :name
      errors.add(:name, :overlapping_domain) if overlaps_domain_in_other_org?
    end

    def validate_space(space)
      unless space && owning_organization && owning_organization.spaces.include?(space)
        raise InvalidSpaceRelation.new(space.guid)
      end
    end

    def validate_organization(org)
      return unless owning_organization
      unless org && owning_organization.id == org.id
        raise InvalidOrganizationRelation.new(org.guid)
      end
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

    def as_summary_json
      {
        :guid => guid,
        :name => name,
        :owning_organization_guid => (owning_organization ? owning_organization.guid : nil)
      }
    end

    def intermediate_domains
      self.class.intermediate_domains(name)
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
        auditors: [user]
      ))

      spaces = Space.filter(Sequel.or(
        developers: [user],
        managers: [user],
        auditors: [user]
      ))

      Sequel.or(
        owning_organization: orgs,
        owning_organization_id: nil,
        spaces: spaces
      )
    end

    def self.default_serving_domain
      @default_serving_domain
    end

    def self.default_serving_domain_name=(name)
      @default_serving_domain_name = name
      if name
        @default_serving_domain = find_or_create_shared_domain(name)
      else
        @default_serving_domain = nil
      end
      name
    end

    def self.default_serving_domain_name
      @default_serving_domain_name
    end

    def self.find_or_create_shared_domain(name)
      logger = Steno.logger("cc.db.domain")
      domain = nil

      Domain.db.transaction(savepoint: true) do
        domain = Domain[:name => name]
        if domain
          logger.info "reusing default serving domain: #{name}"
        else
          logger.info "creating shared serving domain: #{name}"
          domain = Domain.new(:name => name, :wildcard => true)
          domain.save(:validate => false)
        end
      end

      domain
    end

    def self.populate_from_config(config, organization)
      config[:app_domains].each do |domain|
        find_or_create_shared_domain(domain)
      end

      unless config[:app_domains].include?(config[:system_domain])
        raise 'The organization that owns the system domain cannot be nil' unless organization

        find_or_create(
          name: config[:system_domain],
          wildcard: true,
          owning_organization: organization
        )
      end
    end
  end
end
