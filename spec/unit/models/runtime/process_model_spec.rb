require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessModel, type: :model do
    let(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }
    let(:parent_app) { AppModel.make(space: space) }

    let(:domain) { PrivateDomain.make(owning_organization: org) }
    let(:route) { Route.make(domain: domain, space: space) }

    def enable_custom_buildpacks
      TestConfig.override({ disable_custom_buildpacks: nil })
    end

    def disable_custom_buildpacks
      TestConfig.override({ disable_custom_buildpacks: true })
    end

    def expect_validator(validator_class)
      expect(subject.validation_policies).to include(an_instance_of(validator_class))
    end

    def expect_no_validator(validator_class)
      matching_validator = subject.validation_policies.select { |validator| validator.is_a?(validator_class) }
      expect(matching_validator).to be_empty
    end

    before do
      VCAP::CloudController::Seeds.create_seed_stacks
    end

    describe 'Creation' do
      subject(:process) { ProcessModel.new }

      it 'has a default instances' do
        schema_default = ProcessModel.db_schema[:instances][:default].to_i
        expect(process.instances).to eq(schema_default)
      end

      it 'has a default memory' do
        TestConfig.override(default_app_memory: 873565)
        expect(process.memory).to eq(873565)
      end

      context 'has custom ports' do
        subject(:process) { ProcessModel.make(ports: [8081, 8082]) }

        it 'return an app with custom port configuration' do
          expect(process.ports).to eq([8081, 8082])
        end
      end
    end

    describe 'Associations' do
      it { is_expected.to have_timestamp_columns }
      it { is_expected.to have_associated :events, class: AppEvent }

      it 'has service_bindings through the parent app' do
        process  = ProcessModelFactory.make(type: 'potato')
        binding1 = ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space))
        binding2 = ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space))

        expect(process.reload.service_bindings).to match_array([binding1, binding2])
      end

      it 'has route_mappings' do
        process = ProcessModelFactory.make
        route1  = Route.make(space: process.space)
        route2  = Route.make(space: process.space)

        mapping1 = RouteMappingModel.make(app: process.app, route: route1, process_type: process.type)
        mapping2 = RouteMappingModel.make(app: process.app, route: route2, process_type: process.type)

        expect(process.reload.route_mappings).to match_array([mapping1, mapping2])
      end

      it 'has routes through route_mappings' do
        process = ProcessModelFactory.make
        route1  = Route.make(space: process.space)
        route2  = Route.make(space: process.space)

        RouteMappingModel.make(app: process.app, route: route1, process_type: process.type)
        RouteMappingModel.make(app: process.app, route: route2, process_type: process.type)

        expect(process.reload.routes).to match_array([route1, route2])
      end

      it 'has a current_droplet from the parent app' do
        parent_app = AppModel.make
        droplet    = DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE)
        parent_app.update(droplet: droplet)
        process = ProcessModel.make(app: parent_app)

        expect(process.current_droplet).to eq(parent_app.droplet)
      end

      it 'has a space from the parent app' do
        parent_app = AppModel.make(space: space)
        process    = ProcessModel.make
        expect(process.space).not_to eq(space)
        process.update(app: parent_app)
        expect(process.reload.space).to eq(space)
      end

      it 'has an organization from the parent app' do
        parent_app = AppModel.make(space: space)
        process    = ProcessModel.make
        expect(process.organization).not_to eq(org)
        process.update(app: parent_app).reload
        expect(process.organization).to eq(org)
      end

      it 'has a stack from the parent app' do
        stack      = Stack.make
        parent_app = AppModel.make(space: space)
        parent_app.lifecycle_data.update(stack: stack.name)
        process = ProcessModel.make

        expect(process.stack).not_to eq(stack)
        process.update(app: parent_app).reload
        expect(process.stack).to eq(stack)
      end

      context 'when an app has multiple ports bound to the same route' do
        subject(:process) { ProcessModelFactory.make(diego: true, ports: [8080, 9090]) }
        let(:route) { Route.make(host: 'host2', space: process.space, path: '/my%20path') }
        let!(:route_mapping1) { RouteMappingModel.make(app: process.app, route: route, app_port: 8080) }
        let!(:route_mapping2) { RouteMappingModel.make(app: process.app, route: route, app_port: 9090) }

        it 'returns a single associated route' do
          expect(process.routes.size).to eq 1
        end
      end
    end

    describe 'Validations' do
      subject(:process) { ProcessModel.new }

      it { is_expected.to validate_presence :app }

      it 'includes validator policies' do
        expect_validator(InstancesPolicy)
        expect_validator(MaxDiskQuotaPolicy)
        expect_validator(MinDiskQuotaPolicy)
        expect_validator(MetadataPolicy)
        expect_validator(MinMemoryPolicy)
        expect_validator(AppMaxInstanceMemoryPolicy)
        expect_validator(InstancesPolicy)
        expect_validator(HealthCheckPolicy)
        expect_validator(DockerPolicy)
      end

      describe 'org and space quota validator policies' do
        subject(:process) { ProcessModelFactory.make(app: parent_app) }
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org, space_quota_definition: SpaceQuotaDefinition.make(organization: org)) }

        it 'validates org and space using MaxMemoryPolicy' do
          max_memory_policies = process.validation_policies.select { |policy| policy.instance_of? AppMaxMemoryPolicy }
          expect(max_memory_policies.length).to eq(2)
        end

        it 'validates org and space using MaxInstanceMemoryPolicy' do
          max_instance_memory_policies = process.validation_policies.select { |policy| policy.instance_of? AppMaxInstanceMemoryPolicy }
          expect(max_instance_memory_policies.length).to eq(2)
        end

        it 'validates org and space using MaxAppInstancesPolicy' do
          max_app_instances_policy = process.validation_policies.select { |policy| policy.instance_of? MaxAppInstancesPolicy }
          expect(max_app_instances_policy.length).to eq(2)
          targets = max_app_instances_policy.collect(&:quota_definition)
          expect(targets).to match_array([org.quota_definition, space.space_quota_definition])
        end
      end

      describe 'buildpack' do
        subject(:process) { ProcessModel.make }

        it 'allows nil value' do
          process.app.lifecycle_data.update(buildpacks: nil)
          expect {
            process.save
          }.to_not raise_error
          expect(process.buildpack).to eq(AutoDetectionBuildpack.new)
        end

        it 'allows a public url' do
          process.app.lifecycle_data.update(buildpacks: ['git://user@github.com/repo.git'])
          expect {
            process.save
          }.to_not raise_error
          expect(process.buildpack).to eq(CustomBuildpack.new('git://user@github.com/repo.git'))
        end

        it 'allows a public http url' do
          process.app.lifecycle_data.update(buildpacks: ['http://example.com/foo'])
          expect {
            process.save
          }.to_not raise_error
          expect(process.buildpack).to eq(CustomBuildpack.new('http://example.com/foo'))
        end

        it 'allows a buildpack name' do
          admin_buildpack = Buildpack.make
          process.app.lifecycle_data.update(buildpacks: [admin_buildpack.name])
          expect {
            process.save
          }.to_not raise_error

          expect(process.buildpack).to eql(admin_buildpack)
        end

        it 'does not allow a non-url string' do
          process.app.lifecycle_data.buildpacks = ['Hello, world!']
          expect {
            process.save
          }.to raise_error(Sequel::ValidationFailed, /Specified unknown buildpack name: "Hello, world!"/)
        end
      end

      describe 'disk_quota' do
        subject(:process) { ProcessModelFactory.make }

        it 'allows any disk_quota below the maximum' do
          process.disk_quota = 1000
          expect(process).to be_valid
        end

        it 'does not allow a disk_quota above the maximum' do
          process.disk_quota = 3000
          expect(process).to_not be_valid
          expect(process.errors.on(:disk_quota)).to be_present
        end

        it 'does not allow a disk_quota greater than maximum' do
          process.disk_quota = 4096
          expect(process).to_not be_valid
          expect(process.errors.on(:disk_quota)).to be_present
        end
      end

      describe 'health_check_http_endpoint' do
        subject(:process) { ProcessModelFactory.make }

        it 'can be set to the root path' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = '/'
          expect(process).to be_valid
        end

        it 'can be set to a valid uri path' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = '/v2'
          expect(process).to be_valid
        end

        it 'needs a uri path' do
          process.health_check_type = 'http'
          expect(process).to_not be_valid
          expect(process.errors.on(:health_check_http_endpoint)).to be_present
        end

        it 'cannot be set to a relative path' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = 'relative/path'
          expect(process).to_not be_valid
          expect(process.errors.on(:health_check_http_endpoint)).to be_present
        end

        it 'cannot be set to an empty string' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = ' '
          expect(process).to_not be_valid
          expect(process.errors.on(:health_check_http_endpoint)).to be_present
        end
      end

      describe 'health_check_invocation_timeout' do
        subject(:process) { ProcessModelFactory.make }

        it 'can be set for http health checks' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = '/'
          process.health_check_invocation_timeout = 5
          expect(process).to be_valid
        end

        it 'must be a postive integer' do
          process.health_check_type          = 'http'
          process.health_check_http_endpoint = '/'
          process.health_check_invocation_timeout = -13.5
          expect(process).not_to be_valid
        end
      end

      describe 'health_check_type' do
        subject(:process) { ProcessModelFactory.make }

        it "defaults to 'port'" do
          expect(process.health_check_type).to eq('port')
        end

        it "can be set to 'none'" do
          process.health_check_type = 'none'
          expect(process).to be_valid
        end

        it "can be set to 'process'" do
          process.health_check_type = 'process'
          expect(process).to be_valid
        end

        it "can not be set to 'bogus'" do
          process.health_check_type = 'bogus'
          expect(process).to_not be_valid
          expect(process.errors.on(:health_check_type)).to be_present
        end
      end

      describe 'instances' do
        subject(:process) { ProcessModelFactory.make }

        it 'does not allow negative instances' do
          process.instances = -1
          expect(process).to_not be_valid
          expect(process.errors.on(:instances)).to be_present
        end
      end

      describe 'metadata' do
        subject(:process) { ProcessModelFactory.make }

        it 'defaults to an empty hash' do
          expect(ProcessModel.new.metadata).to eql({})
        end

        it 'can be set and retrieved' do
          process.metadata = {}
          expect(process.metadata).to eql({})
        end

        it 'should save direct updates to the metadata' do
          expect(process.metadata).to eq({})
          process.metadata['some_key'] = 'some val'
          expect(process.metadata['some_key']).to eq('some val')
          process.save
          expect(process.metadata['some_key']).to eq('some val')
          process.refresh
          expect(process.metadata['some_key']).to eq('some val')
        end
      end

      describe 'quota' do
        subject(:process) { ProcessModelFactory.make }
        let(:quota) do
          QuotaDefinition.make(memory_limit: 128)
        end
        let(:space_quota) do
          SpaceQuotaDefinition.make(memory_limit: 128, organization: org)
        end

        context 'app update' do
          def act_as_cf_admin
            allow(VCAP::CloudController::SecurityContext).to receive_messages(admin?: true)
            yield
          ensure
            allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_call_original
          end

          let(:org) { Organization.make(quota_definition: quota) }
          let(:space) { Space.make(name: 'hi', organization: org, space_quota_definition: space_quota) }
          let(:parent_app) { AppModel.make(space: space) }
          subject!(:process) { ProcessModelFactory.make(app: parent_app, memory: 64, instances: 2, state: 'STARTED') }

          it 'should raise error when quota is exceeded' do
            process.memory = 65
            expect { process.save }.to raise_error(/quota_exceeded/)
          end

          it 'should not raise error when quota is not exceeded' do
            process.memory = 63
            expect { process.save }.to_not raise_error
          end

          it 'can delete an app that somehow has exceeded its memory quota' do
            quota.memory_limit = 32
            quota.save
            process.memory = 100
            process.save(validate: false)
            expect(process.reload).to_not be_valid
            expect { process.delete }.not_to raise_error
          end

          it 'allows scaling down instances of an app from above quota to below quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 72)
            act_as_cf_admin { org.save }

            expect(process.reload).to_not be_valid
            process.instances = 1

            process.save

            expect(process.reload).to be_valid
            expect(process.instances).to eq(1)
          end

          it 'should raise error when instance quota is exceeded' do
            quota.app_instance_limit = 4
            quota.memory_limit       = 512
            quota.save

            process.instances = 5
            expect { process.save }.to raise_error(/instance_limit_exceeded/)
          end

          it 'should raise error when space instance quota is exceeded' do
            space_quota.app_instance_limit = 4
            space_quota.memory_limit       = 512
            space_quota.save
            quota.memory_limit = 512
            quota.save

            process.instances = 5
            expect { process.save }.to raise_error(/instance_limit_exceeded/)
          end

          it 'raises when scaling down number of instances but remaining above quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 32)
            act_as_cf_admin { org.save }

            process.reload
            process.instances = 1

            expect { process.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)
            process.reload
            expect(process.instances).to eq(2)
          end

          it 'allows stopping an app that is above quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 72)
            act_as_cf_admin { org.save }

            expect(process.reload).to be_started

            process.state = 'STOPPED'
            process.save

            expect(process).to be_stopped
          end

          it 'allows reducing memory from above quota to at/below quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 64)
            act_as_cf_admin { org.save }

            process.memory = 40
            expect { process.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)

            process.memory = 32
            process.save
            expect(process.memory).to eq(32)
          end
        end
      end

      describe 'ports and health check type' do
        subject(:process) { ProcessModelFactory.make }

        describe 'health check type is not "ports"' do
          before do
            process.health_check_type = 'process'
          end

          it 'allows empty ports' do
            process.ports = []
            expect { process.save }.to_not raise_error
          end
        end

        describe 'health check type is "port"' do
          before do
            process.health_check_type = 'port'
          end

          it 'disallows empty ports' do
            process.ports = []
            expect { process.save }.to raise_error(/ports array/)
          end
        end

        describe 'health check type is not specified' do
          it 'disallows empty ports' do
            process = ProcessModel.new(ports: [], app: parent_app)
            expect { process.save }.to raise_error(/ports array/)
          end
        end
      end

      describe 'uniqueness of types for v3 app processes' do
        subject(:process) { ProcessModelFactory.make }
        let(:app_model) { AppModel.make }

        before do
          ProcessModel.make(app: app_model, type: 'web')
        end

        it 'validates uniqueness of process types for the belonging app' do
          msg = 'application process types must be unique (case-insensitive), received: [Web, web]'
          expect {
            ProcessModel.make(app: app_model, type: 'Web')
          }.to raise_error(Sequel::ValidationFailed).with_message(msg)
        end
      end
    end

    describe 'Serialization' do
      it {
        is_expected.to export_attributes(
          :enable_ssh,
          :buildpack,
          :command,
          :console,
          :debug,
          :detected_buildpack,
          :detected_buildpack_guid,
          :detected_start_command,
          :diego,
          :disk_quota,
          :docker_image,
          :environment_json,
          :health_check_http_endpoint,
          :health_check_timeout,
          :health_check_type,
          :instances,
          :memory,
          :name,
          :package_state,
          :package_updated_at,
          :production,
          :space_guid,
          :stack_guid,
          :staging_failed_reason,
          :staging_failed_description,
          :staging_task_id,
          :state,
          :version,
          :ports
        )
      }

      it {
        is_expected.to import_attributes(
          :enable_ssh,
          :app_guid,
          :buildpack,
          :command,
          :console,
          :debug,
          :detected_buildpack,
          :diego,
          :disk_quota,
          :docker_image,
          :environment_json,
          :health_check_http_endpoint,
          :health_check_timeout,
          :health_check_type,
          :instances,
          :memory,
          :name,
          :production,
          :route_guids,
          :service_binding_guids,
          :space_guid,
          :stack_guid,
          :staging_task_id,
          :state,
          :ports
        )
      }
    end

    describe '#in_suspended_org?' do
      subject(:process) { ProcessModel.make }

      context 'when in a space in a suspended organization' do
        before { process.organization.update(status: 'suspended') }
        it 'is true' do
          expect(process).to be_in_suspended_org
        end
      end

      context 'when in a space in an unsuspended organization' do
        before { process.organization.update(status: 'active') }
        it 'is false' do
          expect(process).not_to be_in_suspended_org
        end
      end
    end

    describe '#stack' do
      it 'gets stack from the parent app' do
        desired_stack = Stack.make
        process = ProcessModel.make

        expect(process.stack).not_to eq(desired_stack)
        process.app.lifecycle_data.update(stack: desired_stack.name)
        expect(process.reload.stack).to eq(desired_stack)
      end

      it 'returns the default stack when the parent app does not have a stack' do
        process = ProcessModel.make

        expect(process.stack).not_to eq(Stack.default)
        process.app.lifecycle_data.update(stack: nil)
        expect(process.reload.stack).to eq(Stack.default)
      end
    end

    describe '#execution_metadata' do
      let(:parent_app) { AppModel.make }
      subject(:process) { ProcessModel.make(app: parent_app) }

      context 'when the app has a current droplet' do
        let(:droplet) do
          DropletModel.make(
            app:                parent_app,
            execution_metadata: 'some-other-metadata',
            state:              VCAP::CloudController::DropletModel::STAGED_STATE
          )
        end

        before do
          parent_app.update(droplet: droplet)
        end

        it "returns that droplet's staging metadata" do
          expect(process.execution_metadata).to eq(droplet.execution_metadata)
        end
      end

      context 'when the app does not have a current droplet' do
        it 'returns empty string' do
          expect(process.current_droplet).to be_nil
          expect(process.execution_metadata).to eq('')
        end
      end
    end

    describe '#specified_or_detected_command' do
      subject(:process) { ProcessModelFactory.make }

      before do
        process.current_droplet.update(process_types: { web: 'detected-start-command' })
      end

      context 'when the process has a command' do
        before do
          process.update(command: 'user-specified')
        end

        it 'uses the command on the process' do
          expect(process.specified_or_detected_command).to eq('user-specified')
        end
      end

      context 'when the process does not have a command' do
        before do
          process.update(command: nil)
        end

        it 'returns the detected start command' do
          expect(process.specified_or_detected_command).to eq('detected-start-command')
        end
      end
    end

    describe '#detected_start_command' do
      subject(:process) { ProcessModelFactory.make(type: type) }
      let(:type) { 'web' }

      context 'when the app has a current droplet with a web process' do
        before do
          process.current_droplet.update(process_types: { web: 'run-my-app' })
          process.reload
        end

        it 'returns the web process type command from the droplet' do
          expect(process.detected_start_command).to eq('run-my-app')
        end
      end

      context 'when the app has a current droplet with a webish process' do
        let(:type) { 'web-deployment-11d44a0f-0535-449b-a265-4c01705d85a0' }

        before do
          process.current_droplet.update(process_types: { web: 'run-my-app' })
          process.reload
        end

        it 'returns the web process type command from the droplet' do
          expect(process.detected_start_command).to eq('run-my-app')
        end
      end

      context 'when the app has a current droplet with a non-webish process' do
        let(:type) { 'worker' }

        before do
          process.current_droplet.update(process_types: { worker: 'do-my-work' })
          process.reload
        end

        it 'returns the worker process type command from the droplet' do
          expect(process.detected_start_command).to eq('do-my-work')
        end
      end

      context 'when the app does not have a current droplet' do
        before do
          process.current_droplet.destroy
          process.reload
        end

        it 'returns the empty string' do
          expect(process.current_droplet).to be_nil
          expect(process.detected_start_command).to eq('')
        end
      end
    end

    describe '#environment_json' do
      let(:parent_app) { AppModel.make(environment_variables: { 'key' => 'value' }) }
      let!(:process) { ProcessModel.make(app: parent_app) }

      it 'returns the parent app environment_variables' do
        expect(process.environment_json).to eq({ 'key' => 'value' })
      end
    end

    describe '#database_uri' do
      let(:parent_app) { AppModel.make(environment_variables: { 'jesse' => 'awesome' }, space: space) }
      subject(:process) { ProcessModel.make(app: parent_app) }

      context 'when there are database-like services' do
        before do
          sql_service_plan     = ServicePlan.make(service: Service.make(label: 'elephantsql-n/a'))
          sql_service_instance = ManagedServiceInstance.make(space: space, service_plan: sql_service_plan, name: 'elephantsql-vip-uat')
          ServiceBinding.make(app: parent_app, service_instance: sql_service_instance, credentials: { 'uri' => 'mysql://foo.com' })

          banana_service_plan     = ServicePlan.make(service: Service.make(label: 'chiquita-n/a'))
          banana_service_instance = ManagedServiceInstance.make(space: space, service_plan: banana_service_plan, name: 'chiqiuta-yummy')
          ServiceBinding.make(app: parent_app, service_instance: banana_service_instance, credentials: { 'uri' => 'banana://yum.com' })
        end

        it 'returns database uri' do
          expect(process.reload.database_uri).to eq('mysql2://foo.com')
        end
      end

      context 'when there are non-database-like services' do
        before do
          banana_service_plan     = ServicePlan.make(service: Service.make(label: 'chiquita-n/a'))
          banana_service_instance = ManagedServiceInstance.make(space: space, service_plan: banana_service_plan, name: 'chiqiuta-yummy')
          ServiceBinding.make(app: parent_app, service_instance: banana_service_instance, credentials: { 'uri' => 'banana://yum.com' })

          uncredentialed_service_plan     = ServicePlan.make(service: Service.make(label: 'mysterious-n/a'))
          uncredentialed_service_instance = ManagedServiceInstance.make(space: space, service_plan: uncredentialed_service_plan, name: 'mysterious-mystery')
          ServiceBinding.make(app: parent_app, service_instance: uncredentialed_service_instance, credentials: {})
        end

        it 'returns nil' do
          expect(process.reload.database_uri).to be_nil
        end
      end

      context 'when there are no services' do
        it 'returns nil' do
          expect(process.reload.database_uri).to be_nil
        end
      end

      context 'when the service binding credentials is nil' do
        before do
          banana_service_plan     = ServicePlan.make(service: Service.make(label: 'chiquita-n/a'))
          banana_service_instance = ManagedServiceInstance.make(space: space, service_plan: banana_service_plan, name: 'chiqiuta-yummy')
          ServiceBinding.make(app: parent_app, service_instance: banana_service_instance, credentials: nil)
        end

        it 'returns nil' do
          expect(process.reload.database_uri).to be_nil
        end
      end
    end

    describe 'metadata' do
      it 'deserializes the serialized value' do
        process = ProcessModelFactory.make(
          metadata: { 'jesse' => 'super awesome' },
        )
        expect(process.metadata).to eq('jesse' => 'super awesome')
      end
    end

    describe 'command' do
      it 'stores the command in its own column, not metadata' do
        process = ProcessModelFactory.make(command: 'foobar')
        expect(process.metadata).to eq('command' => 'foobar')
        expect(process.metadata_without_command).to_not eq('command' => 'foobar')
        process.save
        expect(process.metadata).to eq('command' => 'foobar')
        expect(process.metadata_without_command).to_not eq('command' => 'foobar')
        process.refresh
        expect(process.metadata).to eq('command' => 'foobar')
        expect(process.metadata_without_command).to_not eq('command' => 'foobar')
        expect(process.command).to eq('foobar')
      end

      it 'saves the field as nil when initializing to empty string' do
        process = ProcessModelFactory.make(command: '')
        expect(process.command).to eq(nil)
      end

      it 'saves the field as nil when overriding to empty string' do
        process         = ProcessModelFactory.make(command: 'echo hi')
        process.command = ''
        process.save
        process.refresh
        expect(process.command).to eq(nil)
      end

      it 'saves the field as nil when set to nil' do
        process         = ProcessModelFactory.make(command: 'echo hi')
        process.command = nil
        process.save
        process.refresh
        expect(process.command).to eq(nil)
      end

      it 'falls back to metadata value if command is not present' do
        process         = ProcessModelFactory.make(metadata: { command: 'echo hi' })
        process.command = nil
        process.save
        process.refresh
        expect(process.command).to eq('echo hi')
      end
    end

    describe 'console' do
      it 'stores the command in the metadata' do
        process = ProcessModelFactory.make(console: true)
        expect(process.metadata).to eq('console' => true)
        process.save
        expect(process.metadata).to eq('console' => true)
        process.refresh
        expect(process.metadata).to eq('console' => true)
      end

      it 'returns true if console was set to true' do
        process = ProcessModelFactory.make(console: true)
        expect(process.console).to eq(true)
      end

      it 'returns false if console was set to false' do
        process = ProcessModelFactory.make(console: false)
        expect(process.console).to eq(false)
      end

      it 'returns false if console was not set' do
        process = ProcessModelFactory.make
        expect(process.console).to eq(false)
      end
    end

    describe 'debug' do
      it 'stores the command in the metadata' do
        process = ProcessModelFactory.make(debug: 'suspend')
        expect(process.metadata).to eq('debug' => 'suspend')
        process.save
        expect(process.metadata).to eq('debug' => 'suspend')
        process.refresh
        expect(process.metadata).to eq('debug' => 'suspend')
      end

      it 'returns nil if debug was explicitly set to nil' do
        process = ProcessModelFactory.make(debug: nil)
        expect(process.debug).to be_nil
      end

      it 'returns nil if debug was not set' do
        process = ProcessModelFactory.make
        expect(process.debug).to be_nil
      end
    end

    describe 'custom_buildpack_url' do
      subject(:process) { ProcessModel.make(app: parent_app) }
      context 'when a custom buildpack is associated with the app' do
        it 'should be the custom url' do
          process.app.lifecycle_data.update(buildpacks: ['https://example.com/repo.git'])
          expect(process.custom_buildpack_url).to eq('https://example.com/repo.git')
        end
      end

      context 'when an admin buildpack is associated with the app' do
        it 'should be nil' do
          process.app.lifecycle_data.update(buildpacks: [Buildpack.make.name])
          expect(process.custom_buildpack_url).to be_nil
        end
      end

      context 'when no buildpack is associated with the app' do
        it 'should be nil' do
          expect(ProcessModel.make.custom_buildpack_url).to be_nil
        end
      end
    end

    describe 'health_check_timeout' do
      before do
        TestConfig.override({ maximum_health_check_timeout: 512 })
      end

      context 'when the health_check_timeout was not specified' do
        it 'should use nil as health_check_timeout' do
          process = ProcessModelFactory.make
          expect(process.health_check_timeout).to eq(nil)
        end

        it 'should not raise error if value is nil' do
          expect {
            ProcessModelFactory.make(health_check_timeout: nil)
          }.to_not raise_error
        end
      end

      context 'when a valid health_check_timeout is specified' do
        it 'should use that value' do
          process = ProcessModelFactory.make(health_check_timeout: 256)
          expect(process.health_check_timeout).to eq(256)
        end
      end
    end

    describe 'staged?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if package_state is STAGED' do
        expect(process.package_state).to eq('STAGED')
        expect(process.staged?).to be true
      end

      it 'should return false if package_state is PENDING' do
        PackageModel.make(app: process.app)
        process.reload

        expect(process.package_state).to eq('PENDING')
        expect(process.staged?).to be false
      end
    end

    describe 'pending?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if package_state is PENDING' do
        PackageModel.make(app: process.app)
        process.reload

        expect(process.package_state).to eq('PENDING')
        expect(process.pending?).to be true
      end

      it 'should return false if package_state is not PENDING' do
        expect(process.package_state).to eq('STAGED')
        expect(process.pending?).to be false
      end
    end

    describe 'staging?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if the latest_build is STAGING' do
        BuildModel.make(app: process.app, package: process.latest_package, state: BuildModel::STAGING_STATE)
        expect(process.reload.staging?).to be true
      end

      it 'should return false if a new package has been uploaded but a droplet has not been created for it' do
        PackageModel.make(app: process.app)
        process.reload
        expect(process.staging?).to be false
      end

      it 'should return false if the latest_droplet is not STAGING' do
        DropletModel.make(app: process.app, package: process.latest_package, state: DropletModel::STAGED_STATE)
        process.reload
        expect(process.staging?).to be false
      end
    end

    describe 'failed?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if the latest_build is FAILED' do
        process.latest_build.update(state: BuildModel::FAILED_STATE)
        process.reload

        expect(process.package_state).to eq('FAILED')
        expect(process.staging_failed?).to be true
      end

      it 'should return false if latest_build is not FAILED' do
        process.latest_build.update(state: BuildModel::STAGED_STATE)
        process.reload

        expect(process.package_state).to eq('STAGED')
        expect(process.staging_failed?).to be false
      end
    end

    describe '#latest_build' do
      let!(:process) { ProcessModel.make app: parent_app }
      let!(:build1) { BuildModel.make(app: parent_app, state: BuildModel::STAGED_STATE) }
      let!(:build2) { BuildModel.make(app: parent_app, state: BuildModel::STAGED_STATE) }

      it 'should return the most recently created build' do
        expect(process.latest_build).to eq build2
      end
    end

    describe '#package_state' do
      let(:parent_app) { AppModel.make }
      subject(:process) { ProcessModel.make(app: parent_app) }

      it 'calculates the package state' do
        expect(process.latest_package).to be_nil
        expect(process.reload.package_state).to eq('PENDING')
      end
    end

    describe 'needs_staging?' do
      subject(:process) { ProcessModelFactory.make }

      context 'when the app is started' do
        before do
          process.update(state: 'STARTED', instances: 1)
        end

        it 'should return false if the package_hash is nil' do
          process.latest_package.update(package_hash: nil)
          expect(process.needs_staging?).to be_falsey
        end

        it 'should return true if PENDING is set' do
          PackageModel.make(app: process.app, package_hash: 'hash')
          expect(process.reload.needs_staging?).to be true
        end

        it 'should return false if STAGING is set' do
          DropletModel.make(app: process.app, package: process.latest_package, state: DropletModel::STAGING_STATE)
          expect(process.needs_staging?).to be false
        end
      end

      context 'when the app is not started' do
        before do
          process.state = 'STOPPED'
        end

        it 'should return false' do
          expect(process).not_to be_needs_staging
        end
      end
    end

    describe 'started?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if app is STARTED' do
        process.state = 'STARTED'
        expect(process.started?).to be true
      end

      it 'should return false if app is STOPPED' do
        process.state = 'STOPPED'
        expect(process.started?).to be false
      end
    end

    describe 'stopped?' do
      subject(:process) { ProcessModelFactory.make }

      it 'should return true if app is STOPPED' do
        process.state = 'STOPPED'
        expect(process.stopped?).to be true
      end

      it 'should return false if app is STARTED' do
        process.state = 'STARTED'
        expect(process.stopped?).to be false
      end
    end

    describe 'web?' do
      context 'when the process type is web' do
        it 'returns true' do
          expect(ProcessModel.make(type: 'web').web?).to be true
        end
      end

      context 'when the process type is NOT web' do
        it 'returns false' do
          expect(ProcessModel.make(type: 'Bieber').web?).to be false
        end
      end
    end

    describe 'version' do
      subject(:process) { ProcessModelFactory.make }

      it 'should have a version on create' do
        expect(process.version).not_to be_nil
      end

      it 'should update the version when changing :state' do
        process.state = 'STARTED'
        expect { process.save }.to change(process, :version)
      end

      it 'should update the version on update of :state' do
        expect { process.update(state: 'STARTED') }.to change(process, :version)
      end

      context 'for a started app' do
        before { process.update(state: 'STARTED') }

        context 'when lazily backfilling default port values' do
          before do
            # Need to get the app in a state where diego is true but ports are
            # nil. This would only occur on deployments that existed before we
            # added the default port value.
            default_ports = VCAP::CloudController::ProcessModel::DEFAULT_PORTS
            stub_const('VCAP::CloudController::ProcessModel::DEFAULT_PORTS', nil)
            process.update(diego: true)
            stub_const('VCAP::CloudController::ProcessModel::DEFAULT_PORTS', default_ports)
          end

          context 'when changing fields that do not update the version' do
            it 'does not update the version' do
              process.instances = 3

              expect {
                process.save
                process.reload
              }.not_to change { process.version }
            end
          end

          context 'when changing a fields that updates the version' do
            it 'updates the version' do
              process.memory = 17

              expect {
                process.save
                process.reload
              }.to change { process.version }
            end
          end

          context 'when the user updates the port' do
            it 'updates the version' do
              process.ports = [1753]

              expect {
                process.save
                process.reload
              }.to change { process.version }
            end
          end
        end

        it 'should update the version when changing :memory' do
          process.memory = 2048
          expect { process.save }.to change(process, :version)
        end

        it 'should update the version on update of :memory' do
          expect { process.update(memory: 999) }.to change(process, :version)
        end

        it 'should update the version when changing :health_check_type' do
          process.health_check_type = 'none'
          expect { process.save }.to change(process, :version)
        end

        it 'should not update the version when changing :instances' do
          process.instances = 8
          expect { process.save }.to_not change(process, :version)
        end

        it 'should not update the version on update of :instances' do
          expect { process.update(instances: 8) }.to_not change(process, :version)
        end

        it 'should update the version when changing health_check_http_endpoint' do
          process.update(health_check_type: 'http', health_check_http_endpoint: '/oldpath')
          expect {
            process.update(health_check_http_endpoint: '/newpath')
          }.to change { process.version }
        end
      end
    end

    describe '#desired_instances' do
      before do
        @process           = ProcessModel.new
        @process.instances = 10
      end

      context 'when the app is started' do
        before do
          @process.state = 'STARTED'
        end

        it 'is the number of instances specified by the user' do
          expect(@process.desired_instances).to eq(10)
        end
      end

      context 'when the app is not started' do
        before do
          @process.state = 'PENDING'
        end

        it 'is zero' do
          expect(@process.desired_instances).to eq(0)
        end
      end
    end

    describe 'uris' do
      it 'should return the fqdns and paths on the app' do
        process = ProcessModelFactory.make(app: parent_app)
        domain = PrivateDomain.make(name: 'mydomain.com', owning_organization: org)
        route  = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
        RouteMappingModel.make(app: process.app, route: route, process_type: process.type)
        expect(process.uris).to eq(['myhost.mydomain.com/my%20path'])
      end
    end

    describe 'creation' do
      it 'does not create an AppUsageEvent' do
        expect {
          ProcessModel.make
        }.not_to change { AppUsageEvent.count }
      end

      describe 'default_app_memory' do
        before do
          TestConfig.override({ default_app_memory: 200 })
        end

        it 'uses the provided memory' do
          process = ProcessModel.make(memory: 100)
          expect(process.memory).to eq(100)
        end

        it 'uses the default_app_memory when none is provided' do
          process = ProcessModel.make
          expect(process.memory).to eq(200)
        end
      end

      describe 'default disk_quota' do
        before do
          TestConfig.override({ default_app_disk_in_mb: 512 })
        end

        it 'should use the provided quota' do
          process = ProcessModel.make(disk_quota: 256)
          expect(process.disk_quota).to eq(256)
        end

        it 'should use the default quota' do
          process = ProcessModel.make
          expect(process.disk_quota).to eq(512)
        end
      end

      describe 'instance_file_descriptor_limit' do
        before do
          TestConfig.override({ instance_file_descriptor_limit: 200 })
        end

        it 'uses the instance_file_descriptor_limit config variable' do
          process = ProcessModel.make
          expect(process.file_descriptors).to eq(200)
        end
      end

      describe 'default ports' do
        context 'with a diego app' do
          context 'and no ports are specified' do
            it 'does not return a default value' do
              ProcessModel.make(diego: true)
              expect(ProcessModel.last.ports).to be nil
            end
          end

          context 'and ports are specified' do
            it 'uses the ports provided' do
              ProcessModel.make(diego: true, ports: [9999])
              expect(ProcessModel.last.ports).to eq [9999]
            end
          end
        end
      end
    end

    describe 'saving' do
      it 'calls AppObserver.updated', isolation: :truncation do
        process = ProcessModelFactory.make
        expect(ProcessObserver).to receive(:updated).with(process)
        process.update(instances: process.instances + 1)
      end

      context 'when app state changes from STOPPED to STARTED' do
        it 'creates an AppUsageEvent' do
          process = ProcessModelFactory.make
          expect {
            process.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(process)
        end
      end

      context 'when app state changes from STARTED to STOPPED' do
        it 'creates an AppUsageEvent' do
          process = ProcessModelFactory.make(state: 'STARTED')
          expect {
            process.update(state: 'STOPPED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(process)
        end
      end

      context 'when app instances changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          process = ProcessModelFactory.make(state: 'STARTED')
          expect {
            process.update(instances: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(process)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          process = ProcessModelFactory.make(state: 'STOPPED')
          expect {
            process.update(instances: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when app memory changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          process = ProcessModelFactory.make(state: 'STARTED')
          expect {
            process.update(memory: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(process)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          process = ProcessModelFactory.make(state: 'STOPPED')
          expect {
            process.update(memory: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when a custom buildpack was used for staging' do
        it 'creates an AppUsageEvent that contains the custom buildpack url' do
          process = ProcessModelFactory.make(state: 'STOPPED')
          process.app.lifecycle_data.update(buildpacks: ['https://example.com/repo.git'])
          expect {
            process.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event.buildpack_name).to eq('https://example.com/repo.git')
          expect(event).to match_app(process)
        end
      end

      context 'when a detected admin buildpack was used for staging' do
        it 'creates an AppUsageEvent that contains the detected buildpack guid' do
          buildpack = Buildpack.make
          process = ProcessModelFactory.make(state: 'STOPPED')
          process.current_droplet.update(
            buildpack_receipt_buildpack: 'Admin buildpack detect string',
            buildpack_receipt_buildpack_guid: buildpack.guid
          )
          expect {
            process.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event.buildpack_guid).to eq(buildpack.guid)
          expect(event).to match_app(process)
        end
      end
    end

    describe 'destroy' do
      subject(:process) { ProcessModelFactory.make(app: parent_app) }

      it 'notifies the app observer', isolation: :truncation do
        expect(ProcessObserver).to receive(:deleted).with(process)
        process.destroy
      end

      it 'should destroy all dependent crash events' do
        app_event = AppEvent.make(app: process)

        expect {
          process.destroy
        }.to change {
          AppEvent.where(id: app_event.id).count
        }.from(1).to(0)
      end

      it 'creates an AppUsageEvent when the app state is STARTED' do
        process = ProcessModelFactory.make(state: 'STARTED')
        expect {
          process.destroy
        }.to change { AppUsageEvent.count }.by(1)
        expect(AppUsageEvent.last).to match_app(process)
      end

      it 'does not create an AppUsageEvent when the app state is STOPPED' do
        process = ProcessModelFactory.make(state: 'STOPPED')
        expect {
          process.destroy
        }.not_to change { AppUsageEvent.count }
      end

      it 'locks the record when destroying' do
        expect(process).to receive(:lock!)
        process.destroy
      end
    end

    describe 'file_descriptors' do
      subject(:process) { ProcessModelFactory.make }
      its(:file_descriptors) { should == 16_384 }
    end

    describe 'docker_image' do
      subject(:process) { ProcessModelFactory.make(app: parent_app) }

      it 'does not allow a docker package for a buildpack app' do
        process.app.lifecycle_data.update(buildpacks: [Buildpack.make.name])
        PackageModel.make(:docker, app: process.app)
        expect {
          process.save
        }.to raise_error(Sequel::ValidationFailed, /incompatible with buildpack/)
      end

      it 'retrieves the docker image from the package' do
        PackageModel.make(:docker, app: process.app, docker_image: 'someimage')
        expect(process.reload.docker_image).to eq('someimage')
      end
    end

    describe 'docker_username' do
      subject(:process) { ProcessModelFactory.make(app: parent_app) }

      it 'retrieves the docker registry username from the package' do
        PackageModel.make(:docker, app: process.app, docker_image: 'someimage', docker_username: 'user')
        expect(process.reload.docker_username).to eq('user')
      end
    end

    describe 'docker_password' do
      subject(:process) { ProcessModelFactory.make(app: parent_app) }

      it 'retrieves the docker registry password from the package' do
        PackageModel.make(:docker, app: process.app, docker_image: 'someimage', docker_password: 'pass')
        expect(process.reload.docker_password).to eq('pass')
      end
    end

    describe 'diego' do
      subject(:process) { ProcessModelFactory.make }

      it 'defaults to run on diego' do
        expect(process.diego).to be_truthy
      end

      context 'when updating app ports' do
        subject!(:process) { ProcessModelFactory.make(diego: true, state: 'STARTED') }

        before do
          allow(ProcessObserver).to receive(:updated).with(process)
        end

        it 'calls the app observer with the app', isolation: :truncation do
          expect(ProcessObserver).not_to have_received(:updated).with(process)
          process.ports = [1111, 2222]
          process.save
          expect(ProcessObserver).to have_received(:updated).with(process)
        end

        it 'updates the app version' do
          expect {
            process.ports  = [1111, 2222]
            process.memory = 2048
            process.save
          }.to change(process, :version)
        end
      end
    end

    describe '#needs_package_in_current_state?' do
      it 'returns true if started' do
        process = ProcessModel.new(state: 'STARTED')
        expect(process.needs_package_in_current_state?).to eq(true)
      end

      it 'returns false if not started' do
        expect(ProcessModel.new(state: 'STOPPED').needs_package_in_current_state?).to eq(false)
      end
    end

    describe '#docker_ports' do
      describe 'when the app is not docker' do
        subject(:process) { ProcessModelFactory.make(diego: true, docker_image: nil) }

        it 'is an empty array' do
          expect(process.docker_ports).to eq []
        end
      end

      context 'when tcp ports are saved in the droplet metadata' do
        subject(:process) {
          process = ProcessModelFactory.make(diego: true, docker_image: 'some-docker-image')
          process.current_droplet.update(
            execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
          )
          process.reload
        }

        it 'returns an array of the tcp ports' do
          expect(process.docker_ports).to eq([1024, 1025])
        end
      end
    end

    describe 'ports' do
      context 'serialization' do
        it 'serializes and deserializes arrays of integers' do
          process = ProcessModel.make(diego: true, ports: [1025, 1026, 1027, 1028])
          expect(process.ports).to eq([1025, 1026, 1027, 1028])

          process = ProcessModel.make(diego: true, ports: [1024])
          expect(process.ports).to eq([1024])
        end
      end

      context 'docker app' do
        context 'when app is staged' do
          context 'when some tcp ports are exposed' do
            subject(:process) {
              process = ProcessModelFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)
              process.current_droplet.update(
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
              )
              process.reload
            }

            it 'does not change ports' do
              expect(process.ports).to be nil
            end

            it 'returns an auto-detect buildpack' do
              expect(process.buildpack).to eq(AutoDetectionBuildpack.new)
            end

            it 'does not save ports to the database' do
              expect(process.user_provided_ports).to be_nil
            end

            context 'when the user provided ports' do
              before do
                process.ports = [1111]
                process.save
              end

              it 'saves to db and returns the user provided ports' do
                expect(process.user_provided_ports).to eq([1111])
                expect(process.ports).to eq([1111])
              end
            end
          end

          context 'when no tcp ports are exposed' do
            it 'returns the ports that were specified during creation' do
              process = ProcessModelFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)

              process.current_droplet.update(
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"udp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"udp"}]}',
              )
              process.reload

              expect(process.ports).to be nil
              expect(process.user_provided_ports).to be_nil
            end
          end

          context 'when execution metadata is malformed' do
            it 'returns the ports that were specified during creation' do
              process = ProcessModelFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1, ports: [1111])
              process.current_droplet.update(
                execution_metadata: 'some-invalid-json',
              )
              process.reload

              expect(process.user_provided_ports).to eq([1111])
              expect(process.ports).to eq([1111])
            end
          end

          context 'when no ports are specified in the execution metadata' do
            it 'returns the default port' do
              process = ProcessModelFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)
              process.current_droplet.update(
                execution_metadata: '{"cmd":"run.sh"}',
              )
              process.reload

              expect(process.ports).to be nil
              expect(process.user_provided_ports).to be_nil
            end
          end
        end
      end

      context 'buildpack app' do
        context 'when app is not staged' do
          it 'returns the ports that were specified during creation' do
            process = ProcessModel.make(diego: true, ports: [1025, 1026, 1027, 1028])
            expect(process.ports).to eq([1025, 1026, 1027, 1028])
            expect(process.user_provided_ports).to eq([1025, 1026, 1027, 1028])
          end
        end

        context 'when app is staged' do
          context 'with no execution_metadata' do
            it 'returns the ports that were specified during creation' do
              process = ProcessModelFactory.make(diego: true, ports: [1025, 1026, 1027, 1028], instances: 1)
              expect(process.ports).to eq([1025, 1026, 1027, 1028])
              expect(process.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end

          context 'with execution_metadata' do
            it 'returns the ports that were specified during creation' do
              process = ProcessModelFactory.make(diego: true, ports: [1025, 1026, 1027, 1028], instances: 1)
              process.current_droplet.update(
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":8080, "Protocol":"tcp"}]}',
              )
              process.reload

              expect(process.ports).to eq([1025, 1026, 1027, 1028])
              expect(process.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end
        end
      end
    end

    describe 'name' do
      let(:parent_app) { AppModel.make(name: 'parent-app-name') }
      let!(:process) { ProcessModel.make(app: parent_app) }

      it 'returns the parent app name' do
        expect(process.name).to eq('parent-app-name')
      end
    end

    describe 'staging failures' do
      let(:parent_app) { AppModel.make(name: 'parent-app-name') }
      subject(:process) { ProcessModel.make(app: parent_app) }
      let(:error_id) { 'StagingFailed' }
      let(:error_description) { 'stating failed' }

      describe 'when there is a build but no droplet' do
        let!(:build) { BuildModel.make app: parent_app, error_id: error_id, error_description: error_description }

        it 'returns the error_id and error_description from the build' do
          expect(process.staging_failed_reason).to eq(error_id)
          expect(process.staging_failed_description).to eq(error_description)
        end
      end

      describe 'when there is a droplet but no build (legacy case for supporting rolling deploy)' do
        let!(:droplet) { DropletModel.make app: parent_app, error_id: error_id, error_description: error_description }

        it 'returns the error_id and error_description from the build' do
          expect(process.staging_failed_reason).to eq(error_id)
          expect(process.staging_failed_description).to eq(error_description)
        end
      end
    end

    describe 'staging task id' do
      subject(:process) { ProcessModel.make(app: parent_app) }

      context 'when there is a build but no droplet' do
        let!(:build) { BuildModel.make(app: parent_app) }

        it 'is the build guid' do
          expect(process.staging_task_id).to eq(build.guid)
        end
      end

      context 'when there is no build' do
        let!(:droplet) { DropletModel.make(app: parent_app) }

        it 'is the droplet guid if there is no build' do
          expect(process.staging_task_id).to eq(droplet.guid)
        end
      end
    end
  end
end
