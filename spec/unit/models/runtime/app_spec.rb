require 'spec_helper'

module VCAP::CloudController
  RSpec.describe App, type: :model do
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
      matching_validitor = subject.validation_policies.select { |validator| validator.is_a?(validator_class) }
      expect(matching_validitor).to be_empty
    end

    before do
      VCAP::CloudController::Seeds.create_seed_stacks
    end

    describe 'Creation' do
      let(:app) { App.new }

      it 'has a default instances' do
        schema_default = App.db_schema[:instances][:default].to_i
        expect(app.instances).to eq(schema_default)
      end

      it 'has a default memory' do
        TestConfig.override(default_app_memory: 873565)
        expect(app.memory).to eq(873565)
      end

      context 'has custom ports' do
        let(:app) { App.make(ports: [8081, 8082]) }

        context 'with default_to_diego_backend set to true' do
          before { TestConfig.override(default_to_diego_backend: true) }

          it 'return an app with custom port configuration' do
            expect(app.ports).to eq([8081, 8082])
          end
        end

        context 'with default_to_diego_backend set to false' do
          before { TestConfig.override(default_to_diego_backend: false) }

          it 'raises a validation error' do
            expect {
              app.save
            }.to raise_error do |e|
              expect(e.message).
                to include('Custom app ports supported for Diego only. Enable Diego for the app or remove custom app ports')
            end
          end
        end
      end
    end

    describe 'Associations' do
      it { is_expected.to have_timestamp_columns }
      it { is_expected.to have_associated :events, class: AppEvent }

      it 'has service_bindings through the parent app' do
        process = AppFactory.make(type: 'potato')
        binding1 = ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space))
        binding2 = ServiceBinding.make(app: process.app, service_instance: ManagedServiceInstance.make(space: process.space))

        expect(process.reload.service_bindings).to match_array([binding1, binding2])
      end

      it 'has route_mappings' do
        process = AppFactory.make
        route1 = Route.make(space: process.space)
        route2 = Route.make(space: process.space)

        mapping1 = RouteMappingModel.make(app: process.app, route: route1, process_type: process.type)
        mapping2 = RouteMappingModel.make(app: process.app, route: route2, process_type: process.type)

        expect(process.reload.route_mappings).to match_array([mapping1, mapping2])
      end

      it 'has routes through route_mappings' do
        process = AppFactory.make
        route1 = Route.make(space: process.space)
        route2 = Route.make(space: process.space)

        RouteMappingModel.make(app: process.app, route: route1, process_type: process.type)
        RouteMappingModel.make(app: process.app, route: route2, process_type: process.type)

        expect(process.reload.routes).to match_array([route1, route2])
      end

      it 'has a current_droplet from the parent app' do
        parent_app = AppModel.make
        droplet = DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE)
        parent_app.update(droplet: droplet)
        app = App.make(app: parent_app)

        expect(app.current_droplet).to eq(parent_app.droplet)
      end

      it 'has a space from the parent app' do
        parent_app = AppModel.make(space: space)
        process    = App.make
        expect(process.space).not_to eq(space)
        process.update(app: parent_app)
        expect(process.reload.space).to eq(space)
      end

      it 'has an organization from the parent app' do
        parent_app = AppModel.make(space: space)
        process    = App.make
        expect(process.organization).not_to eq(org)
        process.update(app: parent_app).reload
        expect(process.organization).to eq(org)
      end

      it 'has a stack from the parent app' do
        stack      = Stack.make
        parent_app = AppModel.make(space: space)
        parent_app.lifecycle_data.update(stack: stack.name)
        process = App.make

        expect(process.stack).not_to eq(stack)
        process.update(app: parent_app).reload
        expect(process.stack).to eq(stack)
      end

      context 'when an app has multiple ports bound to the same route' do
        let(:app) { AppFactory.make(diego: true, ports: [8080, 9090]) }
        let(:route) { Route.make(host: 'host2', space: app.space, path: '/my%20path') }
        let!(:route_mapping1) { RouteMappingModel.make(app: app, route: route, app_port: 8080) }
        let!(:route_mapping2) { RouteMappingModel.make(app: app, route: route, app_port: 9090) }

        it 'returns a single associated route' do
          expect(app.routes.size).to eq 1
        end
      end
    end

    describe '#after_commit' do
      let(:error) { CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty') }

      # undo happens in after_commit, which only runs if tests use a :truncation strategy instead of :transaction
      context 'when an error happens in AppObserver update' do
        it 'undoes previous changes', isolation: :truncation do
          # use tap to ensure there is an updated_at
          app = AppFactory.make.tap do |a|
            a.instances = 1
            a.save.reload
          end
          original_updated_at = app.updated_at

          allow(AppObserver).to receive(:updated).and_raise(error)

          expect {
            app.update(instances: 2)
          }.to raise_error(CloudController::Errors::ApiError)

          app.reload
          expect(app.instances).to eq(1)
          expect(app.updated_at).to eq(original_updated_at)
        end
      end
    end

    describe 'Validations' do
      let(:app) { AppFactory.make }

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
        subject(:app) { AppFactory.make(app: parent_app) }
        let(:org) { Organization.make }
        let(:space) { Space.make(organization: org, space_quota_definition: SpaceQuotaDefinition.make(organization: org)) }

        it 'validates org and space using MaxMemoryPolicy' do
          max_memory_policies = app.validation_policies.select { |policy| policy.instance_of? AppMaxMemoryPolicy }
          expect(max_memory_policies.length).to eq(2)
        end

        it 'validates org and space using MaxInstanceMemoryPolicy' do
          max_instance_memory_policies = app.validation_policies.select { |policy| policy.instance_of? AppMaxInstanceMemoryPolicy }
          expect(max_instance_memory_policies.length).to eq(2)
        end

        it 'validates org and space using MaxAppInstancesPolicy' do
          max_app_instances_policy = app.validation_policies.select { |policy| policy.instance_of? MaxAppInstancesPolicy }
          expect(max_app_instances_policy.length).to eq(2)
          targets = max_app_instances_policy.collect(&:quota_definition)
          expect(targets).to match_array([org.quota_definition, space.space_quota_definition])
        end
      end

      describe 'buildpack' do
        let(:app) { App.make }

        it 'does allow nil value' do
          app.app.lifecycle_data.update(buildpack: nil)
          expect {
            app.save
          }.to_not raise_error
        end

        it 'does allow a public url' do
          app.app.lifecycle_data.update(buildpack: 'git://user@github.com/repo.git')
          expect {
            app.save
          }.to_not raise_error
        end

        it 'allows a public http url' do
          app.app.lifecycle_data.update(buildpack: 'http://example.com/foo')
          expect {
            app.save
          }.to_not raise_error
        end

        it 'allows a buildpack name' do
          admin_buildpack = Buildpack.make
          app.app.lifecycle_data.update(buildpack: admin_buildpack.name)
          expect {
            app.save
          }.to_not raise_error

          expect(app.buildpack).to eql(admin_buildpack)
        end

        it 'does not allow a non-url string' do
          app.app.lifecycle_data.update(buildpack: 'Hello, world!')
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed, /is not valid public url or a known buildpack name/)
        end
      end

      describe 'disk_quota' do
        it 'allows any disk_quota below the maximum' do
          app.disk_quota = 1000
          expect(app).to be_valid
        end

        it 'does not allow a disk_quota above the maximum' do
          app.disk_quota = 3000
          expect(app).to_not be_valid
          expect(app.errors.on(:disk_quota)).to be_present
        end

        it 'does not allow a disk_quota greater than maximum' do
          app.disk_quota = 4096
          expect(app).to_not be_valid
          expect(app.errors.on(:disk_quota)).to be_present
        end
      end

      describe 'health_check_type' do
        it "defaults to 'port'" do
          expect(app.health_check_type).to eq('port')
        end

        it "can be set to 'none'" do
          app.health_check_type = 'none'
          expect(app).to be_valid
        end

        it "can be set to 'process'" do
          app.health_check_type = 'process'
          expect(app).to be_valid
        end

        it "can not be set to 'bogus'" do
          app.health_check_type = 'bogus'
          expect(app).to_not be_valid
          expect(app.errors.on(:health_check_type)).to be_present
        end
      end

      describe 'instances' do
        it 'does not allow negative instances' do
          app.instances = -1
          expect(app).to_not be_valid
          expect(app.errors.on(:instances)).to be_present
        end
      end

      describe 'metadata' do
        let(:app) { AppFactory.make }

        it 'defaults to an empty hash' do
          expect(App.new.metadata).to eql({})
        end

        it 'can be set and retrieved' do
          app.metadata = {}
          expect(app.metadata).to eql({})
        end

        it 'should save direct updates to the metadata' do
          expect(app.metadata).to eq({})
          app.metadata['some_key'] = 'some val'
          expect(app.metadata['some_key']).to eq('some val')
          app.save
          expect(app.metadata['some_key']).to eq('some val')
          app.refresh
          expect(app.metadata['some_key']).to eq('some val')
        end
      end

      describe 'quota' do
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
          subject!(:app) { AppFactory.make(app: parent_app, memory: 64, instances: 2, state: 'STARTED') }

          it 'should raise error when quota is exceeded' do
            app.memory = 65
            expect { app.save }.to raise_error(/quota_exceeded/)
          end

          it 'should not raise error when quota is not exceeded' do
            app.memory = 63
            expect { app.save }.to_not raise_error
          end

          it 'can delete an app that somehow has exceeded its memory quota' do
            quota.memory_limit = 32
            quota.save
            app.memory = 100
            app.save(validate: false)
            expect(app.reload).to_not be_valid
            expect { app.delete }.not_to raise_error
          end

          it 'allows scaling down instances of an app from above quota to below quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 72)
            act_as_cf_admin { org.save }

            expect(app.reload).to_not be_valid
            app.instances = 1

            app.save

            expect(app.reload).to be_valid
            expect(app.instances).to eq(1)
          end

          it 'should raise error when instance quota is exceeded' do
            quota.app_instance_limit = 4
            quota.memory_limit       = 512
            quota.save

            app.instances = 5
            expect { app.save }.to raise_error(/instance_limit_exceeded/)
          end

          it 'should raise error when space instance quota is exceeded' do
            space_quota.app_instance_limit = 4
            space_quota.memory_limit       = 512
            space_quota.save
            quota.memory_limit = 512
            quota.save

            app.instances = 5
            expect { app.save }.to raise_error(/instance_limit_exceeded/)
          end

          it 'raises when scaling down number of instances but remaining above quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 32)
            act_as_cf_admin { org.save }

            app.reload
            app.instances = 1

            expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)
            app.reload
            expect(app.instances).to eq(2)
          end

          it 'allows stopping an app that is above quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 72)
            act_as_cf_admin { org.save }

            expect(app.reload).to be_started

            app.state = 'STOPPED'
            app.save

            expect(app).to be_stopped
          end

          it 'allows reducing memory from above quota to at/below quota' do
            org.quota_definition = QuotaDefinition.make(memory_limit: 64)
            act_as_cf_admin { org.save }

            app.memory = 40
            expect { app.save }.to raise_error(Sequel::ValidationFailed, /quota_exceeded/)

            app.memory = 32
            app.save
            expect(app.memory).to eq(32)
          end
        end
      end

      describe 'docker credentials' do
        context 'when all credentials are present' do
          it 'succeeds' do
            expect {
              AppFactory.make(docker_credentials_json: {
                'docker_user'     => 'user',
                'docker_password' => 'password',
                'docker_email'    => 'email',
              })
            }.to_not raise_error
          end
        end

        context 'when some credentials are missing' do
          it 'errors' do
            expect {
              AppFactory.make(docker_credentials_json: { 'docker_user' => 'user' })
            }.to raise_error(Sequel::ValidationFailed, /docker_credentials/)
          end
        end

        context 'when no credentials are provided' do
          it 'succeeds' do
            expect {
              AppFactory.make(docker_credentials_json: {})
            }.to_not raise_error
          end
        end

        context 'when docker_credentials_json is nil' do
          it 'succeeds' do
            expect {
              AppFactory.make
            }.to_not raise_error
          end
        end
      end

      describe 'ports and health check type' do
        describe 'health check type is not "ports"' do
          before do
            app.health_check_type = 'process'
          end

          it 'allows empty ports' do
            app.ports = []
            expect { app.save }.to_not raise_error
          end
        end

        describe 'health check type is "port"' do
          before do
            app.health_check_type = 'port'
          end

          it 'disallows empty ports' do
            app.ports = []
            expect { app.save }.to raise_error(/ports array/)
          end
        end

        describe 'health check type is not specified' do
          it 'disallows empty ports' do
            app = App.new(ports: [], app: parent_app)
            expect { app.save }.to raise_error(/ports array/)
          end
        end
      end

      describe 'uniqueness of types for v3 app processes' do
        let(:app_model) { AppModel.make }

        before do
          App.make(app: app_model, type: 'web')
        end

        it 'validates uniqueness of process types for the belonging app' do
          msg = 'application process types must be unique (case-insensitive), received: [Web, web]'
          expect {
            App.make(app: app_model, type: 'Web')
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
          :docker_credentials_json,
          :environment_json,
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
          :docker_credentials_json,
          :environment_json,
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
      let(:app) { App.make }

      context 'when in a space in a suspended organization' do
        before { app.organization.update(status: 'suspended') }
        it 'is true' do
          expect(app).to be_in_suspended_org
        end
      end

      context 'when in a space in an unsuspended organization' do
        before { app.organization.update(status: 'active') }
        it 'is false' do
          expect(app).not_to be_in_suspended_org
        end
      end
    end

    describe '#stack' do
      it 'gets stack from the parent app' do
        desired_stack = Stack.make
        app           = App.make

        expect(app.stack).not_to eq(desired_stack)
        app.app.lifecycle_data.update(stack: desired_stack.name)
        expect(app.reload.stack).to eq(desired_stack)
      end

      it 'returns the default stack when the parent app does not have a stack' do
        app = App.make

        expect(app.stack).not_to eq(Stack.default)
        app.app.lifecycle_data.update(stack: nil)
        expect(app.reload.stack).to eq(Stack.default)
      end
    end

    describe '#buildpack_cache_key' do
      let(:app) { AppFactory.make }
      it 'compose the buildpack cache key from stack name and app guid' do
        app.save
        app.refresh
        expect(app.buildpack_cache_key).to eq("#{app.guid}/#{app.stack.name}")
      end
    end

    describe '#execution_metadata' do
      let(:parent_app) { AppModel.make }
      let(:process) { App.make(app: parent_app) }

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

    describe '#detected_start_command' do
      subject { AppFactory.make }

      context 'when the app has a current droplet' do
        before do
          subject.current_droplet.update(process_types: { web: 'run-my-app' })
          subject.reload
        end

        it 'returns he web process type command from the droplet' do
          expect(subject.detected_start_command).to eq('run-my-app')
        end
      end

      context 'when the app does not have a current droplet' do
        before do
          subject.current_droplet.destroy
          subject.reload
        end

        it 'returns the empty string' do
          expect(subject.current_droplet).to be_nil
          expect(subject.detected_start_command).to eq('')
        end
      end
    end

    describe '#environment_json' do
      let(:parent_app) { AppModel.make(environment_variables: { 'key' => 'value' }) }
      let!(:app) { App.make(app: parent_app) }

      it 'returns the parent app environment_variables' do
        expect(app.environment_json).to eq({ 'key' => 'value' })
      end
    end

    describe 'docker credentials' do
      let(:login_server) { 'https://index.docker.io/v1' }
      let(:user) { 'user' }
      let(:password) { 'password' }
      let(:email) { 'email@example.com' }
      let(:docker_credentials) do
        {
          docker_login_server: login_server,
          docker_user:         user,
          docker_password:     password,
          docker_email:        email
        }
      end

      context 'if credentials change' do
        let(:new_credentials) do
          {
            docker_login_server: login_server,
            docker_user:         user,
            docker_password:     password,
            docker_email:        email
          }
        end
        let(:app) { AppFactory.make(docker_credentials_json: docker_credentials) }

        it 'does not mark an app for restage' do
          expect {
            app.docker_credentials_json = new_credentials
            app.save
          }.not_to change { app.needs_staging? }
        end
      end
    end

    describe '#database_uri' do
      let(:parent_app) { AppModel.make(environment_variables: { 'jesse' => 'awesome' }, space: space) }
      let(:app) { App.make(app: parent_app) }

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
          expect(app.reload.database_uri).to eq('mysql2://foo.com')
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
          expect(app.reload.database_uri).to be_nil
        end
      end

      context 'when there are no services' do
        it 'returns nil' do
          expect(app.reload.database_uri).to be_nil
        end
      end
    end

    describe 'metadata' do
      it 'deserializes the serialized value' do
        app = AppFactory.make(
          metadata: { 'jesse' => 'super awesome' },
        )
        expect(app.metadata).to eq('jesse' => 'super awesome')
      end
    end

    describe 'command' do
      it 'stores the command in its own column, not metadata' do
        app = AppFactory.make(command: 'foobar')
        expect(app.metadata).to eq('command' => 'foobar')
        expect(app.metadata_without_command).to_not eq('command' => 'foobar')
        app.save
        expect(app.metadata).to eq('command' => 'foobar')
        expect(app.metadata_without_command).to_not eq('command' => 'foobar')
        app.refresh
        expect(app.metadata).to eq('command' => 'foobar')
        expect(app.metadata_without_command).to_not eq('command' => 'foobar')
        expect(app.command).to eq('foobar')
      end

      it 'saves the field as nil when initializing to empty string' do
        app = AppFactory.make(command: '')
        expect(app.command).to eq(nil)
      end

      it 'saves the field as nil when overriding to empty string' do
        app         = AppFactory.make(command: 'echo hi')
        app.command = ''
        app.save
        app.refresh
        expect(app.command).to eq(nil)
      end

      it 'saves the field as nil when set to nil' do
        app         = AppFactory.make(command: 'echo hi')
        app.command = nil
        app.save
        app.refresh
        expect(app.command).to eq(nil)
      end

      it 'falls back to metadata value if command is not present' do
        app         = AppFactory.make(metadata: { command: 'echo hi' })
        app.command = nil
        app.save
        app.refresh
        expect(app.command).to eq('echo hi')
      end
    end

    describe 'console' do
      it 'stores the command in the metadata' do
        app = AppFactory.make(console: true)
        expect(app.metadata).to eq('console' => true)
        app.save
        expect(app.metadata).to eq('console' => true)
        app.refresh
        expect(app.metadata).to eq('console' => true)
      end

      it 'returns true if console was set to true' do
        app = AppFactory.make(console: true)
        expect(app.console).to eq(true)
      end

      it 'returns false if console was set to false' do
        app = AppFactory.make(console: false)
        expect(app.console).to eq(false)
      end

      it 'returns false if console was not set' do
        app = AppFactory.make
        expect(app.console).to eq(false)
      end
    end

    describe 'debug' do
      it 'stores the command in the metadata' do
        app = AppFactory.make(debug: 'suspend')
        expect(app.metadata).to eq('debug' => 'suspend')
        app.save
        expect(app.metadata).to eq('debug' => 'suspend')
        app.refresh
        expect(app.metadata).to eq('debug' => 'suspend')
      end

      it 'returns nil if debug was explicitly set to nil' do
        app = AppFactory.make(debug: nil)
        expect(app.debug).to be_nil
      end

      it 'returns nil if debug was not set' do
        app = AppFactory.make
        expect(app.debug).to be_nil
      end
    end

    describe 'custom_buildpack_url' do
      let(:app) { App.make(app: parent_app) }
      context 'when a custom buildpack is associated with the app' do
        it 'should be the custom url' do
          app.app.lifecycle_data.update(buildpack: 'https://example.com/repo.git')
          expect(app.custom_buildpack_url).to eq('https://example.com/repo.git')
        end
      end

      context 'when an admin buildpack is associated with the app' do
        it 'should be nil' do
          app.app.lifecycle_data.update(buildpack: Buildpack.make.name)
          expect(app.custom_buildpack_url).to be_nil
        end
      end

      context 'when no buildpack is associated with the app' do
        it 'should be nil' do
          expect(App.make.custom_buildpack_url).to be_nil
        end
      end
    end

    describe 'health_check_timeout' do
      before do
        TestConfig.override({ maximum_health_check_timeout: 512 })
      end

      context 'when the health_check_timeout was not specified' do
        it 'should use nil as health_check_timeout' do
          app = AppFactory.make
          expect(app.health_check_timeout).to eq(nil)
        end

        it 'should not raise error if value is nil' do
          expect {
            AppFactory.make(health_check_timeout: nil)
          }.to_not raise_error
        end
      end

      context 'when a valid health_check_timeout is specified' do
        it 'should use that value' do
          app = AppFactory.make(health_check_timeout: 256)
          expect(app.health_check_timeout).to eq(256)
        end
      end
    end

    describe 'staged?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is STAGED' do
        expect(app.package_state).to eq('STAGED')
        expect(app.staged?).to be true
      end

      it 'should return false if package_state is PENDING' do
        PackageModel.make(app: app.app)
        app.reload

        expect(app.package_state).to eq('PENDING')
        expect(app.staged?).to be false
      end
    end

    describe 'pending?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is PENDING' do
        PackageModel.make(app: app.app)
        app.reload

        expect(app.package_state).to eq('PENDING')
        expect(app.pending?).to be true
      end

      it 'should return false if package_state is not PENDING' do
        expect(app.package_state).to eq('STAGED')
        expect(app.pending?).to be false
      end
    end

    describe 'staging?' do
      let(:app) { AppFactory.make }

      it 'should return true if the latest_droplet is STAGING' do
        DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::STAGING_STATE)
        app.reload
        expect(app.staging?).to be true
      end

      it 'should return false if a new package has been uploaded but a droplet has not been created for it' do
        PackageModel.make(app: app.app)
        app.reload
        expect(app.staging?).to be false
      end

      it 'should return false if the latest_droplet is not STAGING' do
        DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::STAGED_STATE)
        app.reload
        expect(app.staging?).to be false
      end
    end

    describe 'failed?' do
      let(:app) { AppFactory.make }

      it 'should return true if the latest_droplet is FAILED' do
        app.latest_droplet.update(state: DropletModel::FAILED_STATE)
        app.reload

        expect(app.package_state).to eq('FAILED')
        expect(app.staging_failed?).to be true
      end

      it 'should return false if latest_droplet is not FAILED' do
        app.latest_droplet.update(state: DropletModel::STAGED_STATE)
        app.reload

        expect(app.package_state).to eq('STAGED')
        expect(app.staging_failed?).to be false
      end
    end

    describe '#package_state' do
      let(:parent_app) { AppModel.make }
      subject(:app) { App.make(app: parent_app) }

      context 'when no package exists' do
        it 'is PENDING' do
          expect(app.latest_package).to be_nil
          expect(app.reload.package_state).to eq('PENDING')
        end
      end

      context 'when the package has no hash' do
        before do
          PackageModel.make(app: parent_app, package_hash: nil)
        end

        it 'is PENDING' do
          expect(app.reload.package_state).to eq('PENDING')
        end
      end

      context 'when the package failed to upload' do
        before do
          PackageModel.make(app: parent_app, state: PackageModel::FAILED_STATE)
        end

        it 'is FAILED' do
          expect(app.reload.package_state).to eq('FAILED')
        end
      end

      context 'when the package is available and there is no droplet' do
        before do
          PackageModel.make(app: parent_app, package_hash: 'hash')
        end

        it 'is PENDING' do
          expect(app.reload.package_state).to eq('PENDING')
        end
      end

      context 'when the current droplet is the latest droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          droplet = DropletModel.make(app: parent_app, package: package, state: DropletModel::STAGED_STATE)
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(app.reload.package_state).to eq('STAGED')
        end
      end

      context 'when the current droplet is not the latest droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          DropletModel.make(app: parent_app, package: package, state: DropletModel::STAGED_STATE)
        end

        it 'is PENDING' do
          expect(app.reload.package_state).to eq('PENDING')
        end
      end

      context 'when the latest droplet failed to stage' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          DropletModel.make(app: parent_app, package: package, state: DropletModel::FAILED_STATE)
        end

        it 'is FAILED' do
          expect(app.reload.package_state).to eq('FAILED')
        end
      end

      context 'when there is a newer package than current droplet' do
        before do
          package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE)
          droplet = DropletModel.make(app: parent_app, package: package, state: DropletModel::STAGED_STATE)
          parent_app.update(droplet: droplet)
          PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::READY_STATE, created_at: droplet.created_at + 10.seconds)
        end

        it 'is PENDING' do
          expect(app.reload.package_state).to eq('PENDING')
        end
      end

      context 'when the latest droplet is the current droplet but it does not have a package' do
        before do
          droplet = DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE)
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(app.reload.package_state).to eq('STAGED')
        end
      end

      context 'when the latest droplet has no package but there is a previous package' do
        before do
          previous_package = PackageModel.make(app: parent_app, package_hash: 'hash', state: PackageModel::FAILED_STATE)
          droplet = DropletModel.make(app: parent_app, state: DropletModel::STAGED_STATE, created_at: previous_package.created_at + 10.seconds)
          parent_app.update(droplet: droplet)
        end

        it 'is STAGED' do
          expect(app.reload.package_state).to eq('STAGED')
        end
      end
    end

    describe 'needs_staging?' do
      subject(:app) { AppFactory.make }

      context 'when the app is started' do
        before do
          app.update(state: 'STARTED', instances: 1)
        end

        it 'should return false if the package_hash is nil' do
          app.latest_package.update(package_hash: nil)
          expect(app.needs_staging?).to be_falsey
        end

        it 'should return true if PENDING is set' do
          PackageModel.make(app: app.app, package_hash: 'hash')
          expect(app.reload.needs_staging?).to be true
        end

        it 'should return false if STAGING is set' do
          DropletModel.make(app: app.app, package: app.latest_package, state: DropletModel::STAGING_STATE)
          expect(app.needs_staging?).to be false
        end
      end

      context 'when the app is not started' do
        before do
          app.state = 'STOPPED'
        end

        it 'should return false' do
          expect(app).not_to be_needs_staging
        end
      end

      context 'when the app has no instances' do
        before do
          app.state     = 'STARTED'
          app.instances = 0
        end

        it { is_expected.not_to be_needs_staging }
      end
    end

    describe 'started?' do
      let(:app) { AppFactory.make }

      it 'should return true if app is STARTED' do
        app.state = 'STARTED'
        expect(app.started?).to be true
      end

      it 'should return false if app is STOPPED' do
        app.state = 'STOPPED'
        expect(app.started?).to be false
      end
    end

    describe 'stopped?' do
      let(:app) { AppFactory.make }

      it 'should return true if app is STOPPED' do
        app.state = 'STOPPED'
        expect(app.stopped?).to be true
      end

      it 'should return false if app is STARTED' do
        app.state = 'STARTED'
        expect(app.stopped?).to be false
      end
    end

    describe 'version' do
      let(:app) { AppFactory.make }

      it 'should have a version on create' do
        expect(app.version).not_to be_nil
      end

      it 'should update the version when changing :state' do
        app.state = 'STARTED'
        expect { app.save }.to change(app, :version)
      end

      it 'should update the version on update of :state' do
        expect { app.update(state: 'STARTED') }.to change(app, :version)
      end

      context 'for a started app' do
        before { app.update(state: 'STARTED') }

        context 'when lazily backfilling default port values' do
          before do
            # Need to get the app in a state where diego is true but ports are
            # nil. This would only occur on deployments that existed before we
            # added the default port value.
            default_ports = VCAP::CloudController::App::DEFAULT_PORTS
            stub_const('VCAP::CloudController::App::DEFAULT_PORTS', nil)
            app.update(diego: true)
            stub_const('VCAP::CloudController::App::DEFAULT_PORTS', default_ports)
          end

          context 'when changing fields that do not update the version' do
            it 'does not update the version' do
              app.instances = 3

              expect {
                app.save
                app.reload
              }.not_to change { app.version }
            end
          end

          context 'when changing a fields that updates the version' do
            it 'updates the version' do
              app.memory = 17

              expect {
                app.save
                app.reload
              }.to change { app.version }
            end
          end

          context 'when the user updates the port' do
            it 'updates the version' do
              app.ports = [1753]

              expect {
                app.save
                app.reload
              }.to change { app.version }
            end
          end
        end

        it 'should update the version when changing :memory' do
          app.memory = 2048
          expect { app.save }.to change(app, :version)
        end

        it 'should update the version on update of :memory' do
          expect { app.update(memory: 999) }.to change(app, :version)
        end

        it 'should update the version when changing :health_check_type' do
          app.health_check_type = 'none'
          expect { app.save }.to change(app, :version)
        end

        it 'should not update the version when changing :instances' do
          app.instances = 8
          expect { app.save }.to_not change(app, :version)
        end

        it 'should not update the version on update of :instances' do
          expect { app.update(instances: 8) }.to_not change(app, :version)
        end

        it 'should update the version when changing enable_ssh' do
          expect {
            app.update(enable_ssh: !app.enable_ssh)
          }.to change { app.version }
        end
      end
    end

    describe '#desired_instances' do
      before do
        @app           = App.new
        @app.instances = 10
      end

      context 'when the app is started' do
        before do
          @app.state = 'STARTED'
        end

        it 'is the number of instances specified by the user' do
          expect(@app.desired_instances).to eq(10)
        end
      end

      context 'when the app is not started' do
        before do
          @app.state = 'PENDING'
        end

        it 'is zero' do
          expect(@app.desired_instances).to eq(0)
        end
      end
    end

    describe 'uris' do
      it 'should return the fqdns and paths on the app' do
        app    = AppFactory.make(app: parent_app)
        domain = PrivateDomain.make(name: 'mydomain.com', owning_organization: org)
        route  = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
        RouteMappingModel.make(app: app.app, route: route, process_type: app.type)
        expect(app.uris).to eq(['myhost.mydomain.com/my%20path'])
      end
    end

    describe 'creation' do
      it 'does not create an AppUsageEvent' do
        expect {
          App.make
        }.not_to change { AppUsageEvent.count }
      end

      describe 'default enable_ssh' do
        context 'when enable_ssh is set explicitly' do
          it 'does not overwrite it with the default' do
            app1 = App.make(enable_ssh: true)
            expect(app1.enable_ssh).to eq(true)

            app2 = App.make(enable_ssh: false)
            expect(app2.enable_ssh).to eq(false)
          end
        end

        context 'when global allow_ssh config is true' do
          before do
            TestConfig.override({ allow_app_ssh_access: true })
          end

          context 'when space allow_ssh config is true' do
            let(:parent_app) { AppModel.make(:buildpack, space: space) }

            before do
              space.update(allow_ssh: true)
            end

            it 'sets enable_ssh to true' do
              app = App.make(app: parent_app)
              expect(app.enable_ssh).to eq(true)
            end
          end

          context 'when space allow_ssh config is false' do
            let(:parent_app) { AppModel.make(:buildpack, space: space) }

            before do
              space.update(allow_ssh: false)
            end

            it 'sets enable_ssh to false' do
              app = App.make(app: parent_app)
              expect(app.enable_ssh).to eq(false)
            end
          end
        end

        context 'when global allow_ssh config is false' do
          before do
            TestConfig.override({ allow_app_ssh_access: false })
          end

          it 'sets enable_ssh to false' do
            app = App.make
            expect(app.enable_ssh).to eq(false)
          end
        end
      end

      describe 'default_app_memory' do
        before do
          TestConfig.override({ default_app_memory: 200 })
        end

        it 'uses the provided memory' do
          app = App.make(memory: 100)
          expect(app.memory).to eq(100)
        end

        it 'uses the default_app_memory when none is provided' do
          app = App.make
          expect(app.memory).to eq(200)
        end
      end

      describe 'default disk_quota' do
        before do
          TestConfig.override({ default_app_disk_in_mb: 512 })
        end

        it 'should use the provided quota' do
          app = App.make(disk_quota: 256)
          expect(app.disk_quota).to eq(256)
        end

        it 'should use the default quota' do
          app = App.make
          expect(app.disk_quota).to eq(512)
        end
      end

      describe 'instance_file_descriptor_limit' do
        before do
          TestConfig.override({ instance_file_descriptor_limit: 200 })
        end

        it 'uses the instance_file_descriptor_limit config variable' do
          app = App.make
          expect(app.file_descriptors).to eq(200)
        end
      end

      describe 'default ports' do
        context 'with a diego app' do
          context 'and no ports are specified' do
            it 'does not return a default value' do
              App.make(diego: true)
              expect(App.last.ports).to be nil
            end
          end

          context 'and ports are specified' do
            it 'uses the ports provided' do
              App.make(diego: true, ports: [9999])
              expect(App.last.ports).to eq [9999]
            end
          end
        end
      end
    end

    describe 'saving' do
      it 'calls AppObserver.updated', isolation: :truncation do
        app = AppFactory.make
        expect(AppObserver).to receive(:updated).with(app)
        app.update(instances: app.instances + 1)
      end

      context 'when AppObserver.updated fails' do
        let(:app) { AppFactory.make }
        let(:undo_app) { double(:undo_app_changes, undo: true) }

        context 'when the app is a dea app' do
          it 'should undo any change', isolation: :truncation do
            allow(UndoAppChanges).to receive(:new).with(app).and_return(undo_app)

            expect(AppObserver).to receive(:updated).once.with(app).
              and_raise(CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty'))
            expect(undo_app).to receive(:undo)
            expect { app.update(state: 'STARTED') }.to raise_error(CloudController::Errors::ApiError, /app package hash/)
          end
        end

        context 'when the app is a diego app' do
          before do
            allow(UndoAppChanges).to receive(:new)
          end

          let(:app) { AppFactory.make(diego: true) }

          it 'does not call UndoAppChanges', isolation: :truncation do
            expect(AppObserver).to receive(:updated).once.with(app).
              and_raise(CloudController::Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty'))
            expect { app.update(state: 'STARTED') }.to raise_error(CloudController::Errors::ApiError, /app package hash/)
            expect(UndoAppChanges).not_to have_received(:new)
          end
        end

        it 'does not call UndoAppChanges when its not an ApiError', isolation: :truncation do
          expect(AppObserver).to receive(:updated).once.with(app).and_raise('boom')
          expect(UndoAppChanges).not_to receive(:new)
          expect { app.update(state: 'STARTED') }.to raise_error('boom')
        end
      end

      context 'when app state changes from STOPPED to STARTED' do
        it 'creates an AppUsageEvent' do
          app = AppFactory.make
          expect {
            app.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end
      end

      context 'when app state changes from STARTED to STOPPED' do
        it 'creates an AppUsageEvent' do
          app = AppFactory.make(state: 'STARTED')
          expect {
            app.update(state: 'STOPPED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end
      end

      context 'when app instances changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          app = AppFactory.make(state: 'STARTED')
          expect {
            app.update(instances: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          app = AppFactory.make(state: 'STOPPED')
          expect {
            app.update(instances: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when app memory changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          app = AppFactory.make(state: 'STARTED')
          expect {
            app.update(memory: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          app = AppFactory.make(state: 'STOPPED')
          expect {
            app.update(memory: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when a custom buildpack was used for staging' do
        it 'creates an AppUsageEvent that contains the custom buildpack url' do
          app = AppFactory.make(state: 'STOPPED')
          app.app.lifecycle_data.update(buildpack: 'https://example.com/repo.git')
          expect {
            app.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event.buildpack_name).to eq('https://example.com/repo.git')
          expect(event).to match_app(app)
        end
      end

      context 'when a detected admin buildpack was used for staging' do
        it 'creates an AppUsageEvent that contains the detected buildpack guid' do
          buildpack = Buildpack.make
          app       = AppFactory.make(state: 'STOPPED')
          app.current_droplet.update(
            buildpack_receipt_buildpack:      'Admin buildpack detect string',
            buildpack_receipt_buildpack_guid: buildpack.guid
          )
          expect {
            app.update(state: 'STARTED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event.buildpack_guid).to eq(buildpack.guid)
          expect(event).to match_app(app)
        end
      end
    end

    describe 'destroy' do
      let(:app) { AppFactory.make(app: parent_app) }

      it 'notifies the app observer', isolation: :truncation do
        expect(AppObserver).to receive(:deleted).with(app)
        app.destroy
      end

      it 'should destroy all dependent crash events' do
        app_event = AppEvent.make(app: app)

        expect {
          app.destroy
        }.to change {
          AppEvent.where(id: app_event.id).count
        }.from(1).to(0)
      end

      it 'creates an AppUsageEvent when the app state is STARTED' do
        app = AppFactory.make(state: 'STARTED')
        expect {
          app.destroy
        }.to change { AppUsageEvent.count }.by(1)
        expect(AppUsageEvent.last).to match_app(app)
      end

      it 'does not create an AppUsageEvent when the app state is STOPPED' do
        app = AppFactory.make(state: 'STOPPED')
        expect {
          app.destroy
        }.not_to change { AppUsageEvent.count }
      end

      it 'locks the record when destroying' do
        expect(app).to receive(:lock!)
        app.destroy
      end
    end

    describe 'file_descriptors' do
      subject { AppFactory.make }
      its(:file_descriptors) { should == 16_384 }
    end

    describe 'docker_image' do
      subject(:app) { AppFactory.make(app: parent_app) }

      it 'does not allow a docker package for a buildpack app' do
        app.app.lifecycle_data.update(buildpack: Buildpack.make.name)
        PackageModel.make(:docker, app: app.app)
        expect {
          app.save
        }.to raise_error(Sequel::ValidationFailed, /incompatible with buildpack/)
      end
    end

    describe 'diego' do
      subject { AppFactory.make }

      context 'default values' do
        context 'when the config specifies dea as the default backend' do
          before { TestConfig.override(default_to_diego_backend: false) }

          it 'does not run on diego' do
            expect(subject.diego).to be_falsey
          end
        end

        context 'when the config specifies diego as the default backend' do
          before { TestConfig.override(default_to_diego_backend: true) }

          it 'runs on diego' do
            expect(subject.diego).to be_truthy
          end
        end
      end

      context 'when updating app ports' do
        let!(:app) { AppFactory.make(diego: true, state: 'STARTED') }

        before do
          allow(AppObserver).to receive(:updated).with(app)
        end

        it 'calls the app observer with the app', isolation: :truncation do
          expect(AppObserver).not_to have_received(:updated).with(app)
          app.ports = [1111, 2222]
          app.save
          expect(AppObserver).to have_received(:updated).with(app)
        end

        it 'updates the app version' do
          expect {
            app.ports  = [1111, 2222]
            app.memory = 2048
            app.save
          }.to change(app, :version)
        end
      end
    end

    describe '#needs_package_in_current_state?' do
      it 'returns true if started' do
        app = App.new(state: 'STARTED')
        expect(app.needs_package_in_current_state?).to eq(true)
      end

      it 'returns false if not started' do
        expect(App.new(state: 'STOPPED').needs_package_in_current_state?).to eq(false)
      end
    end

    describe '#docker_ports' do
      describe 'when the app is not docker' do
        let(:app) { AppFactory.make(diego: true, docker_image: nil) }

        it 'is an empty array' do
          expect(app.docker_ports).to eq []
        end
      end

      context 'when tcp ports are saved in the droplet metadata' do
        let(:app) {
          app = AppFactory.make(diego: true, docker_image: 'some-docker-image')
          app.current_droplet.update(
            droplet_hash:       'the-droplet-hash',
            execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
          )
          app.reload
        }

        it 'returns an array of the tcp ports' do
          expect(app.docker_ports).to eq([1024, 1025])
        end
      end
    end

    describe 'ports' do
      context 'serialization' do
        it 'serializes and deserializes arrays of integers' do
          app = App.make(diego: true, ports: [1025, 1026, 1027, 1028])
          expect(app.ports).to eq([1025, 1026, 1027, 1028])

          app = App.make(diego: true, ports: [1024])
          expect(app.ports).to eq([1024])
        end
      end

      context 'docker app' do
        context 'when app is staged' do
          context 'when some tcp ports are exposed' do
            let(:app) {
              app = AppFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)
              app.current_droplet.update(
                droplet_hash:       'the-droplet-hash',
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
              )
              app.reload
            }

            it 'does not change ports' do
              expect(app.ports).to be nil
            end

            it 'does not save ports to the database' do
              expect(app.user_provided_ports).to be_nil
            end

            context 'when the user provided ports' do
              before do
                app.ports = [1111]
                app.save
              end

              it 'saves to db and returns the user provided ports' do
                expect(app.user_provided_ports).to eq([1111])
                expect(app.ports).to eq([1111])
              end
            end
          end

          context 'when no tcp ports are exposed' do
            it 'returns the ports that were specified during creation' do
              app = AppFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)

              app.current_droplet.update(
                droplet_hash:       'the-droplet-hash',
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"udp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"udp"}]}',
              )
              app.reload

              expect(app.ports).to be nil
              expect(app.user_provided_ports).to be_nil
            end
          end

          context 'when execution metadata is malformed' do
            it 'returns the ports that were specified during creation' do
              app = AppFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1, ports: [1111])
              app.current_droplet.update(
                droplet_hash:       'the-droplet-hash',
                execution_metadata: 'some-invalid-json',
              )
              app.reload

              expect(app.user_provided_ports).to eq([1111])
              expect(app.ports).to eq([1111])
            end
          end

          context 'when no ports are specified in the execution metadata' do
            it 'returns the default port' do
              app = AppFactory.make(diego: true, docker_image: 'some-docker-image', instances: 1)
              app.current_droplet.update(
                droplet_hash:       'the-droplet-hash',
                execution_metadata: '{"cmd":"run.sh"}',
              )
              app.reload

              expect(app.ports).to be nil
              expect(app.user_provided_ports).to be_nil
            end
          end
        end
      end

      context 'buildpack app' do
        context 'when app is not staged' do
          it 'returns the ports that were specified during creation' do
            app = App.make(diego: true, ports: [1025, 1026, 1027, 1028])
            expect(app.ports).to eq([1025, 1026, 1027, 1028])
            expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
          end
        end

        context 'when app is staged' do
          context 'with no execution_metadata' do
            it 'returns the ports that were specified during creation' do
              app = AppFactory.make(diego: true, ports: [1025, 1026, 1027, 1028], instances: 1)
              expect(app.ports).to eq([1025, 1026, 1027, 1028])
              expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end

          context 'with execution_metadata' do
            it 'returns the ports that were specified during creation' do
              app = AppFactory.make(diego: true, ports: [1025, 1026, 1027, 1028], instances: 1)
              app.current_droplet.update(
                droplet_hash:       'the-droplet-hash',
                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":8080, "Protocol":"tcp"}]}',
              )
              app.reload

              expect(app.ports).to eq([1025, 1026, 1027, 1028])
              expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end
        end
      end

      context 'switching from diego to dea' do
        let(:app) { AppFactory.make(app: parent_app, state: 'STARTED', diego: true, ports: [8080, 2345]) }
        let(:route) { Route.make(host: 'host', space: app.space) }
        let(:route2) { Route.make(host: 'host', space: app.space) }
        let!(:route_mapping_1) { RouteMappingModel.make(app: parent_app, route: route, process_type: app.type) }
        let!(:route_mapping_2) { RouteMappingModel.make(app: parent_app, route: route2, process_type: app.type) }

        before do
          app.diego = false
        end

        it 'should not update the version' do
          expect {
            app.save
            app.reload
          }.not_to change { app.version }
        end

        it 'should update the version when the user updates a version-updating field' do
          app.memory = 17

          expect {
            app.save
            app.reload
          }.to change { app.version }
        end

        it 'fails validations when ports are specified at the same time' do
          app.ports = [45453]

          expect {
            app.save
            app.reload
          }.to raise_error Sequel::ValidationFailed
        end

        it 'should set ports to nil' do
          expect(app.save.reload.ports).to be_nil
        end

        context 'app with one or more routes and multiple ports' do
          before do
            route_mapping_2.update(app_port: 2345)
          end

          it 'should raise an error' do
            expect {
              app.save
            }.to raise_error Sequel::ValidationFailed, /Multiple app ports not allowed/
          end
        end
      end
    end

    describe 'name' do
      let(:parent_app) { AppModel.make(name: 'parent-app-name') }
      let!(:app) { App.make(app: parent_app) }

      it 'returns the parent app name' do
        expect(app.name).to eq('parent-app-name')
      end
    end
  end
end
