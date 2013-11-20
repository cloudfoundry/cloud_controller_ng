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
        config[:quota_definitions].each do |name, values|
          quota = QuotaDefinition.find(:name => name.to_s)

          if quota
            quota.set(values)
            if quota.modified?
              Steno.logger.warn("seeds.quota-collision", name: name, values: values)
            end
          else
            QuotaDefinition.create(values.merge(:name => name.to_s))
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

        org = Organization.find(:name => config[:system_domain_organization])
        if org
          org.set(quota_definition: quota_definition)
          if org.modified?
            Steno.logger.warn("seeds.system-domain-organization.collision", existing_quota_name: org.refresh.quota_definition.name)
          end
        else
          Organization.create(:name => config[:system_domain_organization], quota_definition: quota_definition)
        end
      end

      def create_seed_domains(config, system_org)
        Domain.populate_from_config(config, system_org)
        Organization.all.each { |org| org.add_inheritable_domains }
      end
    end
  end
end
