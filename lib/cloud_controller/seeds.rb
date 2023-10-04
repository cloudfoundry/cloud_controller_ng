require 'cloud_controller/adjective_noun_generator'

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
        seed_encryption_key_sentinels(config)
      end

      def create_seed_shared_isolation_segment(config)
        shared_isolation_segment_model = IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)

        if shared_isolation_segment_model
          unless shared_isolation_segment_model.name.eql?(config.get(:shared_isolation_segment_name))
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
            Steno.logger('cc.seeds').warn('seeds.quota-collision', name:, values:) if quota.modified?
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
        raise ArgumentError.new('Missing default quota definition in config file') unless quota_definition

        org = Organization.find(name: config.get(:system_domain_organization))
        if org
          org.set(quota_definition:)
          Steno.logger('cc.seeds').warn('seeds.system-domain-organization.collision', existing_quota_name: org.refresh.quota_definition.name) if org.modified?
          org
        else
          Organization.create(name: config.get(:system_domain_organization), quota_definition: quota_definition)
        end
      end

      def with_retries(tries=9)
        base = tries
        begin
          yield
        rescue RoutingApi::RoutingApiUnavailable
          unless (tries -= 1).zero?
            # Final wait for 51.2 seconds for 9 tries
            sleep(0.1 * (2**(base - tries - 1)))
            retry
          end
          raise
        end
      end

      def create_seed_domains(config, system_org)
        with_retries do
          domains = parsed_domains(config.get(:app_domains))
          system_domain = config.get(:system_domain)

          domains.each do |domain|
            attrs = {
              name: domain['name'],
              router_group_guid: find_routing_guid(domain),
              internal: domain['internal']
            }
            SharedDomain.find_or_create(**attrs.compact)
          end

          if CloudController::DomainDecorator.new(system_domain).has_sub_domain?(test_domains: domains.pluck('name'))
            Config.config.get(:system_hostnames).each do |hostnames|
              domains.each do |app_domain|
                raise 'App domain cannot overlap with reserved system hostnames' if hostnames + '.' + system_domain == app_domain['name']
              end
            end

            router_group_guid = find_routing_guid({ 'name' => system_domain })
            SharedDomain.find_or_create(name: system_domain, router_group_guid: router_group_guid)
          else
            raise 'A system_domain_organization must be provided if the system_domain is not shared with (in the list of) app_domains' unless system_org

            domain = Domain.find(name: system_domain)

            if domain
              Steno.logger('cc.seeds').warn('seeds.system-domain.collision', organization: domain.owning_organization) if domain.owning_organization != system_org
            else
              PrivateDomain.create({ owning_organization: system_org, name: system_domain })
            end
          end
        end
      end

      def find_routing_guid(domain)
        return unless domain.key?('router_group_name')

        router_group_name = domain['router_group_name']
        router_group_guid = routing_api_client.router_group_guid(router_group_name)
        raise "Unknown router_group_name specified: #{router_group_name}" if router_group_guid.nil?

        router_group_guid
      end

      def create_seed_security_groups(config)
        return unless config.get(:security_group_definitions) && SecurityGroup.count == 0

        config.get(:security_group_definitions).each do |security_group|
          seed_security_group = security_group.dup

          seed_security_group['staging_default'] = true if config.get(:default_staging_security_groups).include?(security_group['name'])

          seed_security_group['running_default'] = true if config.get(:default_running_security_groups).include?(security_group['name'])

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
        app_domains.map do |domain|
          if domain.is_a?(Hash)
            domain
          else
            { 'name' => domain }
          end
        end
      end

      def seed_encryption_key_sentinels(config)
        encryption_keys = config.get(:database_encryption, :keys)
        return if encryption_keys.blank?

        adjective_noun_generator = AdjectiveNounGenerator.new
        encryption_keys.each do |label, key|
          label_string = label.to_s
          next if EncryptionKeySentinelModel.where(encryption_key_label: label_string).present?

          sentinel_string = adjective_noun_generator.generate
          salt = Encryptor.generate_salt
          encrypted_value = Encryptor.encrypt_raw(sentinel_string, key, salt)
          EncryptionKeySentinelModel.create(
            expected_value: sentinel_string,
            encrypted_value: encrypted_value,
            encryption_key_label: label_string,
            salt: salt,
            encryption_iterations: Encryptor::ENCRYPTION_ITERATIONS
          )
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
