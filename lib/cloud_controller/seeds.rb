module VCAP::CloudController
  module Seeds
    class << self
      def write_seed_data(config)
        create_seed_quota_definitions(config)
        create_seed_stacks(config)
        system_org = create_seed_organizations(config)
        create_seed_domains(config, system_org)
      end

      def create_seed_quota_definitions(config)
        config[:quota_definitions].each do |k, v|
          QuotaDefinition.update_or_create(:name => k.to_s) do |r|
            r.update_from_hash(v)
          end
        end
      end

      def create_seed_stacks(_)
        Stack.populate
      end

      def create_seed_organizations(config)
        # It is assumed that if no system domain organization is present,
        # then the 'system domain' feature is unused.
        return unless config[:system_domain_organization]

        quota_definition = QuotaDefinition.find(:name => "paid")

        unless quota_definition
          raise ArgumentError, "Missing 'paid' quota definition in config file"
        end

        Organization.find_or_create(:name => config[:system_domain_organization]) do |org|
          org.quota_definition = quota_definition
        end
      end

      def create_seed_domains(config, system_org)
        Domain.populate_from_config(config, system_org)
      end
    end
  end
end
