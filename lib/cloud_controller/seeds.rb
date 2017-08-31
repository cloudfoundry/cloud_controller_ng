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
        create_seed_environment_variable_groups
        create_seed_shared_isolation_segment(config)
      end

      def create_seed_shared_isolation_segment(config)
        shared_isolation_segment_model = IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

        if shared_isolation_segment_model
          if !shared_isolation_segment_model.name.eql?(config.get(:shared_isolation_segment_name))
            shared_isolation_segment_model.update(name: config.get(:shared_isolation_segment_name))
          end
        else
          IsolationSegmentModel.create(name: config.get(:shared_isolation_segment_name), guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
        end
      end

      def create_seed_quota_definitions(config)
        config.get(:quota_definitions).each do |name, values|
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
        return unless config.get(:system_domain_organization)

        quota_definition = QuotaDefinition.default
        unless quota_definition
          raise ArgumentError.new('Missing default quota definition in config file')
        end

        org = Organization.find(name: config.get(:system_domain_organization))
        if org
          org.set(quota_definition: quota_definition)
          if org.modified?
            Steno.logger('cc.seeds').warn('seeds.system-domain-organization.collision', existing_quota_name: org.refresh.quota_definition.name)
          end
          org
        else
          Organization.create(name: config.get(:system_domain_organization), quota_definition: quota_definition)
        end
      end

      def create_seed_domains(config, system_org)
        domains = parsed_domains(config.get(:app_domains))
        system_domain = config.get(:system_domain)

        domains.each do |domain|
          domain_name = domain['name']

          router_group_guid = find_routing_guid(domain)

          SharedDomain.find_or_create(domain_name, router_group_guid)
        end

        if CloudController::DomainHelper.is_sub_domain?(domain: system_domain, test_domains: domains.map { |domain_hash| domain_hash['name'] })
          Config.config.get(:system_hostnames).each do |hostnames|
            domains.each do |app_domain|
              raise 'App domain cannot overlap with reserved system hostnames' if hostnames + '.' + system_domain == app_domain['name']
            end
          end

          router_group_guid = find_routing_guid({ 'name' => system_domain })
          SharedDomain.find_or_create(system_domain, router_group_guid)
        else
          raise 'A system_domain_organization must be provided if the system_domain is not shared with (in the list of) app_domains' unless system_org

          domain = Domain.find(name: system_domain)

          if domain
            if domain.owning_organization != system_org
              Steno.logger('cc.seeds').warn('seeds.system-domain.collision', organization: domain.owning_organization)
            end
          else
            PrivateDomain.create({ owning_organization: system_org, name: system_domain })
          end
        end
      end

      def find_routing_guid(domain)
        if domain.key?('router_group_name')
          router_group_name = domain['router_group_name']
          router_group_guid = routing_api_client.router_group_guid(router_group_name)
          raise "Unknown router_group_name specified: #{router_group_name}" if router_group_guid.nil?
          router_group_guid
        end
      end

      def create_seed_security_groups(config)
        return unless config.get(:security_group_definitions) && SecurityGroup.count == 0

        config.get(:security_group_definitions).each do |security_group|
          seed_security_group = security_group.dup

          if config.get(:default_staging_security_groups).include?(security_group['name'])
            seed_security_group['staging_default'] = true
          end

          if config.get(:default_running_security_groups).include?(security_group['name'])
            seed_security_group['running_default'] = true
          end

          SecurityGroup.create(seed_security_group)
        end
      end

      def create_seed_lockings
        Locking.find_or_create(name: 'buildpacks')
      end

      def create_seed_environment_variable_groups
        begin
          EnvironmentVariableGroup.running
        rescue Sequel::UniqueConstraintViolation
          # swallow error, nothing to seed so we have succeeded
        end

        begin
          EnvironmentVariableGroup.staging
        rescue Sequel::UniqueConstraintViolation
          # swallow error, nothing to seed so we have succeeded
        end
      end

      def parsed_domains(app_domains)
        if app_domains[0].is_a?(String)
          parsed = []
          app_domains.each do |d|
            parsed << { 'name' => d }
          end
          parsed
        else
          app_domains
        end
      end

      private

      def routing_api_client
        CloudController::DependencyLocator.instance.routing_api_client
      end

      def domain_overlap(parsed_domain, system_config)
        overlap = false
        parsed_domain.each do |d|
          overlap = true if d['name'].include?(system_config)
        end
        overlap
      end
    end
  end
end
