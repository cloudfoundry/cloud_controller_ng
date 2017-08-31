require 'spec_helper'
require 'cloud_controller/seeds'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Seeds do
    let(:config) { TestConfig.config_instance.clone }

    describe '.create_seed_stacks' do
      it 'populates stacks' do
        expect(Stack).to receive(:populate)
        Seeds.create_seed_stacks
      end
    end

    describe '.create_seed_shared_isolation_segment' do
      before do
        IsolationSegmentModel.dataset.destroy
      end

      it 'creates the shared isolation segment' do
        expect {
          Seeds.create_seed_shared_isolation_segment(config)
        }.to change { IsolationSegmentModel.count }.from(0).to(1)

        shared_isolation_segment_model = IsolationSegmentModel.first
        expect(shared_isolation_segment_model.name).to eq('shared')
        expect(shared_isolation_segment_model.guid).to eq(IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
      end

      context 'when the shared isolation segment already exists' do
        before do
          Seeds.create_seed_shared_isolation_segment(config)
        end

        context 'and the name does not change' do
          it 'does not update the isolation segment' do
            expect_any_instance_of(IsolationSegmentModel).to_not receive(:update)
            Seeds.create_seed_shared_isolation_segment(config)
          end
        end

        context 'and the name changes' do
          it 'sets the name of the shared segment to the new value' do
            expect {
              Seeds.create_seed_shared_isolation_segment(Config.new(shared_isolation_segment_name: 'original-name'))
            }.to_not change { IsolationSegmentModel.count }

            shared_isolation_segment_model = IsolationSegmentModel.first
            expect(shared_isolation_segment_model.name).to eq('original-name')
            expect(shared_isolation_segment_model.guid).to eq(IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
          end

          context 'and the name is already taken' do
            let(:isolation_segment_model) { IsolationSegmentModel.make }

            # this means that it will fail our deployment. To correct this issue we could
            # redeploy with what the old 'shared' isolation segment name
            it 'raises some kind of error TBD' do
              expect {
                Seeds.create_seed_shared_isolation_segment(Config.new(shared_isolation_segment_name: isolation_segment_model.name))
              }.to raise_error(Sequel::ValidationFailed, /must be unique/)
            end
          end
        end
      end
    end

    describe '.create_seed_quota_definitions' do
      let(:config) do
        Config.new(
          quota_definitions: {
            'small' => {
              non_basic_services_allowed: false,
              total_routes: 10,
              total_services: 10,
              memory_limit: 1024,
              total_reserved_route_ports: 10,
            },

            'default' => {
              non_basic_services_allowed: true,
              total_routes: 1000,
              total_services: 20,
              memory_limit: 1_024_000,
              total_reserved_route_ports: 5,
            },
          },
          default_quota_definition: 'default',
        )
      end

      before do
        Organization.dataset.destroy
        QuotaDefinition.dataset.destroy
      end

      context 'when there are no quota definitions' do
        it 'makes them all' do
          expect {
            Seeds.create_seed_quota_definitions(config)
          }.to change { QuotaDefinition.count }.from(0).to(2)

          small_quota = QuotaDefinition[name: 'small']
          expect(small_quota.non_basic_services_allowed).to eq(false)
          expect(small_quota.total_routes).to eq(10)
          expect(small_quota.total_services).to eq(10)
          expect(small_quota.memory_limit).to eq(1024)
          expect(small_quota.total_reserved_route_ports).to eq(10)

          default_quota = QuotaDefinition[name: 'default']
          expect(default_quota.non_basic_services_allowed).to eq(true)
          expect(default_quota.total_routes).to eq(1000)
          expect(default_quota.total_services).to eq(20)
          expect(default_quota.memory_limit).to eq(1_024_000)
          expect(default_quota.total_reserved_route_ports).to eq(5)
        end
      end

      context 'when all the quota definitions exist already' do
        before do
          Seeds.create_seed_quota_definitions(config)
        end

        context 'when the existing records exactly match the config' do
          it 'does not create duplicates' do
            expect {
              Seeds.create_seed_quota_definitions(config)
            }.not_to change { QuotaDefinition.count }

            small_quota = QuotaDefinition[name: 'small']
            expect(small_quota.non_basic_services_allowed).to eq(false)
            expect(small_quota.total_routes).to eq(10)
            expect(small_quota.total_services).to eq(10)
            expect(small_quota.memory_limit).to eq(1024)
            expect(small_quota.total_reserved_route_ports).to eq(10)

            default_quota = QuotaDefinition[name: 'default']
            expect(default_quota.non_basic_services_allowed).to eq(true)
            expect(default_quota.total_routes).to eq(1000)
            expect(default_quota.total_services).to eq(20)
            expect(default_quota.memory_limit).to eq(1_024_000)
            expect(default_quota.total_reserved_route_ports).to eq(5)
          end
        end

        context 'when there are records with names that match but other fields that do not match' do
          it 'warns' do
            mock_logger = double
            allow(Steno).to receive(:logger).and_return(mock_logger)
            config.set(:quota_definitions,
                       config.get(:quota_definitions).deep_merge('small' => { total_routes: 2 }))

            expect(mock_logger).to receive(:warn).with('seeds.quota-collision', hash_including(name: 'small'))

            Seeds.create_seed_quota_definitions(config)
          end
        end
      end
    end

    describe '.create_seed_organizations' do
      context 'when system domain organization is missing in the configuration' do
        it 'does not create an organization' do
          config_without_org = config.clone
          config_without_org.set(:system_domain_organization, nil)

          expect {
            Seeds.create_seed_organizations(config_without_org)
          }.not_to change { Organization.count }
        end
      end

      context 'when system domain organization exists in the configuration' do
        before do
          Organization.dataset.destroy
          QuotaDefinition.dataset.destroy
        end

        context 'when default quota definition is missing in configuraition' do
          it 'raises error' do
            expect do
              Seeds.create_seed_organizations(config)
            end.to raise_error(ArgumentError, /missing default quota definition in config file/i)
          end
        end

        context 'when default quota definition exists' do
          before do
            QuotaDefinition.make(name: 'default')
          end

          it 'creates the system organization when the organization does not already exist' do
            expect {
              Seeds.create_seed_organizations(config)
            }.to change { Organization.count }.from(0).to(1)

            org = Organization.first
            expect(org.quota_definition.name).to eq('default')
            expect(org.name).to eq('the-system_domain-org-name')
          end

          it 'warns when the system organization exists and has a different quota' do
            Seeds.create_seed_organizations(config)
            org = Organization.find(name: 'the-system_domain-org-name')
            QuotaDefinition.make(name: 'runaway')
            org.quota_definition = QuotaDefinition.find(name: 'runaway')
            org.save(validate: false) # See tracker story #61090364

            mock_logger = double
            allow(Steno).to receive(:logger).and_return(mock_logger)

            expect(mock_logger).to receive(:warn).with('seeds.system-domain-organization.collision', existing_quota_name: 'runaway')

            Seeds.create_seed_organizations(config)
          end
        end
      end
    end

    describe '.create_seed_domains' do
      let(:config) do
        Config.new(
          app_domains: app_domains,
          system_domain: system_domain,
          system_domain_organization: 'the-system-org',
          quota_definitions: {
            'default' => {
              non_basic_services_allowed: true,
              total_routes: 1000,
              total_services: 20,
              memory_limit: 1_024_000,
            },
          },
          default_quota_definition: 'default'
        )
      end
      let(:system_org) { Organization.find(name: 'the-system-org') }
      let(:system_domain) { 'system.example.com' }

      before do
        Domain.dataset.destroy
        Organization.dataset.destroy
        QuotaDefinition.dataset.destroy
        QuotaDefinition.make(name: 'default')
        Seeds.create_seed_organizations(config)
      end

      context 'when the app domains do not include the system domain' do
        let(:app_domains) { ['app.some-other-domain.com'] }

        it 'makes a shared domain for each app domain, and a private domain for the system domain' do
          Seeds.create_seed_domains(config, Organization.find(name: 'the-system-org'))
          expect(Domain.shared_domains.map(&:name)).to eq(['app.some-other-domain.com'])
          expect(Domain.private_domains.map(&:name)).to eq(['system.example.com'])
        end

        it 'raises if the system org is not specified' do
          expect { Seeds.create_seed_domains(config, nil) }.to raise_error(RuntimeError, /system_domain_organization must be provided/)
        end

        it 'creates the system domain if the system domain does not exist' do
          Seeds.create_seed_domains(config, system_org)

          system_domain = Domain.find(name: config.get(:system_domain))
          expect(system_domain.owning_organization).to eq(system_org)
        end

        it 'warns if the system domain exists but has different attributes from the seed' do
          mock_logger = double(info: nil)
          allow(Steno).to receive(:logger).and_return(mock_logger)

          expect(mock_logger).to receive(:warn).with('seeds.system-domain.collision', instance_of(Hash))

          PrivateDomain.create(
            name: config.get(:system_domain),
            owning_organization: Organization.make
          )
          Seeds.create_seed_domains(config, system_org)
        end

        context 'when the app domains include a subdomain of the system domain' do
          let(:app_domains) { ['app.example.com'] }
          let(:system_domain) { 'example.com' }

          it 'adds both as shared domains' do
            Seeds.create_seed_domains(config, Organization.find(name: 'the-system-org'))
            expect(Domain.shared_domains.map(&:name)).to match_array(['app.example.com', 'example.com'])
            expect(Domain.private_domains.map(&:name)).to eq([])
          end
        end

        context 'when the system domain already exists as a shared domain' do
          let(:app_domains) { ['app.example.com'] }
          let(:system_domain) { 'system.example.com' }

          before do
            SharedDomain.make(name: 'system.example.com')
          end

          it 'that shared domain is not modified' do
            Seeds.create_seed_domains(config, Organization.find(name: 'the-system-org'))
            expect(Domain.shared_domains.map(&:name)).to match_array(['app.example.com', 'system.example.com'])
            expect(Domain.private_domains.map(&:name)).to eq([])
          end
        end

        context 'when the app domain is one of the system hostnames + system domain' do
          let(:app_domains) { ['uaa.example.com'] }
          let(:system_domain) { 'example.com' }

          before do
            TestConfig.override(system_hostnames: ['api', 'uaa'])
            SharedDomain.make(name: 'example.com')
          end

          it 'returns an error about app domain overlapping with system hostnames' do
            expect { Seeds.create_seed_domains(config, Organization.find(name: 'the-system-org')) }.
              to raise_error(RuntimeError, /App domain cannot overlap with reserved system hostnames/)
          end
        end

        context 'when the app domains include the system domain' do
          let(:app_domains) { ['app.example.com'] }

          before do
            config.set(:app_domains, config.get(:app_domains) + [config.get(:system_domain)])
          end

          it 'makes a shared domain for each app domain, including the system domain' do
            Seeds.create_seed_domains(config, Organization.find(name: 'the-system-org'))
            expect(Domain.shared_domains.map(&:name)).to eq(config.get(:app_domains))
          end
        end

        context 'when a router group name is specified' do
          let(:client) { instance_double(VCAP::CloudController::RoutingApi::Client, enabled?: true) }
          let(:app_domains) { [{ 'name' => 'app.example.com', 'router_group_name' => 'default-tcp' }] }

          before do
            locator = CloudController::DependencyLocator.instance
            allow(locator).to receive(:routing_api_client).and_return(client)
            allow(client).to receive(:router_group_guid).with('default-tcp').and_return('some-router-guid')
          end

          it 'seeds the shared domains with the router group guid' do
            Seeds.create_seed_domains(config, system_org)
            expect(Domain.shared_domains.map(&:name)).to eq(['app.example.com'])
            expect(Domain.shared_domains.map(&:router_group_guid)).to eq(['some-router-guid'])
          end
        end

        context 'when a nonexistent router group name is specified' do
          let(:app_domains) { [{ 'name' => 'app.example.com', 'router_group_name' => 'not-there' }] }
          let(:client) { instance_double(VCAP::CloudController::RoutingApi::Client, enabled?: true) }
          before do
            locator = CloudController::DependencyLocator.instance
            allow(locator).to receive(:routing_api_client).and_return(client)
            allow(client).to receive(:router_group_guid).and_return(nil)
          end

          it 'raises and error' do
            expect {
              Seeds.create_seed_domains(config, system_org)
            }.to raise_error('Unknown router_group_name specified: not-there')
          end
        end

        context 'when routing api is disabled' do
          let(:disabled_client) { RoutingApi::DisabledClient.new }
          let(:app_domains) { [{ 'name' => 'app.example.com', 'router_group_name' => 'default-tcp' }] }

          before do
            locator = CloudController::DependencyLocator.instance
            allow(locator).to receive(:routing_api_client).and_return(disabled_client)
          end

          it 'raises an error' do
            expect {
              Seeds.create_seed_domains(config, system_org)
            }.to raise_error(RoutingApi::RoutingApiDisabled)
          end
        end
      end
    end

    describe '.create_seed_security_groups' do
      let(:config) do
        Config.new(
          security_group_definitions: [
            {
              'name' => 'staging_default',
              'rules' => []
            },
            {
              'name' => 'running_default',
              'rules' => []
            },
            {
              'name' => 'non_default',
              'rules' => []
            }
          ],
          default_staging_security_groups: ['staging_default'],
          default_running_security_groups: ['running_default']
        )
      end

      context 'when there are no security groups configured in the system' do
        before do
          SecurityGroup.dataset.destroy
        end

        it 'creates the security groups specified and sets the correct defaults' do
          expect {
            Seeds.create_seed_security_groups(config)
          }.to change { SecurityGroup.count }.by(3)

          staging_def = SecurityGroup.find(name: 'staging_default')
          expect(staging_def.staging_default).to be true
          expect(staging_def.running_default).to be false

          running_def = SecurityGroup.find(name: 'running_default')
          expect(running_def.staging_default).to be false
          expect(running_def.running_default).to be true

          non_def = SecurityGroup.find(name: 'non_default')
          expect(non_def.staging_default).to be false
          expect(non_def.running_default).to be false
        end

        context 'when the staging and running default are the same' do
          before do
            config.set(:default_running_security_groups, 'staging_default')
          end

          it 'creates the security groups specified and sets the correct defaults' do
            expect {
              Seeds.create_seed_security_groups(config)
            }.to change { SecurityGroup.count }.by(3)

            staging_def = SecurityGroup.find(name: 'staging_default')
            expect(staging_def.staging_default).to be true
            expect(staging_def.running_default).to be true

            running_def = SecurityGroup.find(name: 'running_default')
            expect(running_def.staging_default).to be false
            expect(running_def.running_default).to be false

            non_def = SecurityGroup.find(name: 'non_default')
            expect(non_def.staging_default).to be false
            expect(non_def.running_default).to be false
          end
        end

        context 'when there are no default staging and running groups' do
          before do
            config.set(:default_running_security_groups, [])
            config.set(:default_staging_security_groups, [])
          end

          it 'creates the security groups specified and sets the correct defaults' do
            expect {
              Seeds.create_seed_security_groups(config)
            }.to change { SecurityGroup.count }.by(3)

            staging_def = SecurityGroup.find(name: 'staging_default')
            expect(staging_def.staging_default).to be false
            expect(staging_def.running_default).to be false

            running_def = SecurityGroup.find(name: 'running_default')
            expect(running_def.staging_default).to be false
            expect(running_def.running_default).to be false

            non_def = SecurityGroup.find(name: 'non_default')
            expect(non_def.staging_default).to be false
            expect(non_def.running_default).to be false
          end
        end

        context 'when there are more than one default staging and running groups' do
          before do
            config.set(:default_running_security_groups, ['running_default', 'non_default'])
            config.set(:default_staging_security_groups, ['staging_default', 'non_default'])
          end

          it 'creates the security groups specified and sets the correct defaults' do
            expect {
              Seeds.create_seed_security_groups(config)
            }.to change { SecurityGroup.count }.by(3)

            staging_def = SecurityGroup.find(name: 'staging_default')
            expect(staging_def.staging_default).to be true
            expect(staging_def.running_default).to be false

            running_def = SecurityGroup.find(name: 'running_default')
            expect(running_def.staging_default).to be false
            expect(running_def.running_default).to be true

            non_def = SecurityGroup.find(name: 'non_default')
            expect(non_def.staging_default).to be true
            expect(non_def.running_default).to be true
          end
        end

        context 'when no security group seed data is specified in the config' do
          let(:config) do
            Config.new({})
          end

          it 'does nothing' do
            expect {
              Seeds.create_seed_security_groups(config)
            }.not_to change { SecurityGroup.count }
          end
        end
      end

      context 'when there are exisiting security groups' do
        before do
          SecurityGroup.make(name: 'EXISTING SECURITY GROUP')
        end

        it 'does nothing' do
          expect {
            Seeds.create_seed_security_groups(config)
          }.not_to change { SecurityGroup.count }
        end
      end
    end

    describe '.create_seed_environment_variable_groups' do
      context 'when there are not running and staging environment variable groups' do
        before do
          EnvironmentVariableGroup.dataset.destroy
        end

        it 'creates the running and staging environment variable groups' do
          expect(EnvironmentVariableGroup.find(name: 'running')).to be_nil
          expect(EnvironmentVariableGroup.find(name: 'staging')).to be_nil
          Seeds.create_seed_environment_variable_groups
          expect(EnvironmentVariableGroup.find(name: 'running')).not_to be_nil
          expect(EnvironmentVariableGroup.find(name: 'staging')).not_to be_nil
        end

        context 'if another instance of CC wins a race and creates the group while we are creating the group' do
          it 'continues gracefully when running already exists' do
            allow(EnvironmentVariableGroup).to receive(:running).and_raise(Sequel::UniqueConstraintViolation.new)

            expect {
              Seeds.create_seed_environment_variable_groups
            }.not_to raise_error
          end

          it 'continues gracefully when staging already exists' do
            allow(EnvironmentVariableGroup).to receive(:staging).and_raise(Sequel::UniqueConstraintViolation.new)

            expect {
              Seeds.create_seed_environment_variable_groups
            }.not_to raise_error
          end
        end
      end
    end

    describe '.parsed_domains' do
      context 'when app domain is an array of strings' do
        let(:app_domains) { ['string1.com', 'string2.com'] }

        it 'returns an array of hashes' do
          expected_result = [{ 'name' => 'string1.com' }, { 'name' => 'string2.com' }]
          expect(Seeds.parsed_domains(app_domains)).to eq(expected_result)
        end
      end
      context 'when app domains is an array of hashes' do
        let(:app_domains) { [{ 'name' => 'string1.com',
                               'router_group_name' => 'some-name' },
                             { 'name' => 'string2.com' }]
        }
        it 'returns in the same format' do
          expected_result = [{ 'name' => 'string1.com', 'router_group_name' => 'some-name' },
                             { 'name' => 'string2.com' }]
          expect(Seeds.parsed_domains(app_domains)).to eq(expected_result)
        end
      end
    end
  end
end
