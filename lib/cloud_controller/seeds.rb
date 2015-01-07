module VCAP::CloudController
  module Seeds
    class << self
      def write_seed_data(config)
        create_seed_quota_definitions(config)
        create_seed_stacks
        create_seed_security_groups(config)
        system_org = create_seed_organizations(config)
        create_seed_domains(config, system_org)
        create_seed_lockings
      end

      def create_seed_quota_definitions(config)
        config[:quota_definitions].each do |name, values|
          quota = QuotaDefinition.find(name: name.to_s)

          if quota
            quota.set(values)
            if quota.modified?
              Steno.logger('cc.seeds').warn('seeds.quota-collision', name: name, values: values)
            end
          else
            QuotaDefinition.create(values.merge(name: name.to_s))
          end
        end
      end

      def create_seed_stacks
        Stack.populate
      end

      def create_seed_organizations(config)
        # It is assumed that if no system domain organization is present,
        # then the 'system domain' feature is unused.
        return unless config[:system_domain_organization]

        quota_definition = QuotaDefinition.default
        unless quota_definition
          raise ArgumentError.new('Missing default quota definition in config file')
        end

        org = Organization.find(name: config[:system_domain_organization])
        if org
          org.set(quota_definition: quota_definition)
          if org.modified?
            Steno.logger('cc.seeds').warn('seeds.system-domain-organization.collision', existing_quota_name: org.refresh.quota_definition.name)
          end
          org
        else
          Organization.create(name: config[:system_domain_organization], quota_definition: quota_definition)
        end
      end

      def create_seed_domains(config, system_org)
        config[:app_domains].each do |domain|
          shared_domain = SharedDomain.find_or_create(domain)

          if domain == config[:system_domain]
            shared_domain.save
          end
        end

        unless config[:app_domains].include?(config[:system_domain])
          raise 'The organization that owns the system domain cannot be nil' unless system_org

          domain = Domain.find(name: config[:system_domain])

          if domain
            if domain.owning_organization != system_org
              Steno.logger('cc.seeds').warn('seeds.system-domain.collision', organization: domain.owning_organization)
            end
          else
            PrivateDomain.create({ owning_organization: system_org, name: config[:system_domain] })
          end
        end
      end

      def create_seed_security_groups(config)
        return unless config[:security_group_definitions] && SecurityGroup.count == 0

        config[:security_group_definitions].each do |security_group|
          seed_security_group = security_group.dup

          if config[:default_staging_security_groups].include?(security_group['name'])
            seed_security_group['staging_default'] = true
          end

          if config[:default_running_security_groups].include?(security_group['name'])
            seed_security_group['running_default'] = true
          end

          SecurityGroup.create(seed_security_group)
        end
      end

      def create_seed_lockings
        Locking.find_or_create(name: 'buildpacks')
      end
    end
  end
end
