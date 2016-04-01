# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  describe App, type: :model do
    let(:org) { Organization.make }
    let(:space) { Space.make(organization: org) }

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

    it_behaves_like 'a model with an encrypted attribute' do
      let(:value_to_encrypt) { '{"foo":"bar"}' }
      let(:encrypted_attr) { :environment_json_without_serialization }
      let(:storage_column) { :encrypted_environment_json }
      let(:attr_salt) { :salt }
    end

    describe 'Creation' do
      let(:app) { App.new }

      it 'has a default instances' do
        schema_default = App.db_schema[:instances][:default].to_i
        expect(app.instances).to eq(schema_default)
      end

      it 'has a default memory' do
        allow(VCAP::CloudController::Config.config).to receive(:[]).with(:default_app_memory).and_return(873565)
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
      it { is_expected.to have_associated :droplets }
      it do
        is_expected.to have_associated :service_bindings, associated_instance: ->(app) {
                                                                                 service_instance = ManagedServiceInstance.make(space: app.space)
                                                                                 ServiceBinding.make(service_instance: service_instance, app: app)
                                                                               }
      end
      it { is_expected.to have_associated :events, class: AppEvent }
      it { is_expected.to have_associated :admin_buildpack, class: Buildpack }
      it { is_expected.to have_associated :space }
      it { is_expected.to have_associated :stack }
      it { is_expected.to have_associated :routes, associated_instance: ->(app) { Route.make(space: app.space) } }
      it { is_expected.to have_associated :route_mappings, associated_instance: -> (app) { RouteMapping.make(app_id: app.id, route_id: Route.make(space: app.space).id) } }

      context 'when an app has multiple ports bound to the same route' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
        let(:route) { Route.make(host: 'host2', space: space, path: '/my%20path') }
        let!(:route_mapping1) { RouteMapping.make(app: app, route: route, app_port: 8080) }
        let!(:route_mapping2) { RouteMapping.make(app: app, route: route, app_port: 9090) }

        it 'returns a single associated route' do
          expect(app.routes.size).to eq 1
        end
      end

      context 'when associating a route with a diego app' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [9090, 7070]) }
        let(:route) { Route.make(host: 'host2', space: space, path: '/my%20path') }

        before do
          app.add_route(route)
        end

        it 'maps the route to the first app port in the ports field of the app' do
          expect(app.route_mappings.first.user_provided_app_port).to eq(9090)
          expect(app.route_mappings.first.app_port).to eq(9090)
        end
      end

      context 'when an app has no user provided ports' do
        let(:app) { AppFactory.make(space: space, diego: true) }
        let(:route) { Route.make(host: 'host2', space: space, path: '/my%20path') }

        before do
          app.add_route(route)
        end

        it 'does not save an app_port for the route mapping' do
          expect(app.route_mappings.first.user_provided_app_port).to be_nil
          expect(app.route_mappings.first.app_port).to eq(8080)
        end
      end

      context 'with Docker app' do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let!(:docker_app) do
          AppFactory.make(space: space, docker_image: 'some-image', state: 'STARTED')
        end

        context 'and Docker disabled' do
          before do
            FeatureFlag.find(name: 'diego_docker').update(enabled: false)
          end

          it 'should associate an app with a route' do
            expect { docker_app.add_route(route) }.not_to raise_error
          end
        end
      end

      context 'with non-docker app' do
        let(:non_docker_app) do
          AppFactory.make(space: space)
        end

        context 'and Docker disabled' do
          before do
            FeatureFlag.create(name: 'diego_docker', enabled: false)
          end

          it 'should associate an app with a route' do
            expect { non_docker_app.add_route(route) }.not_to raise_error
          end
        end
      end
    end

    describe 'Validations' do
      let(:app) { AppFactory.make }

      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :space }
      it { is_expected.to validate_uniqueness [:space_id, :name] }
      it { is_expected.to strip_whitespace :name }

      it 'includes validator policies' do
        expect_validator(InstancesPolicy)
        expect_validator(AppEnvironmentPolicy)
        expect_validator(MaxDiskQuotaPolicy)
        expect_validator(MinDiskQuotaPolicy)
        expect_validator(MetadataPolicy)
        expect_validator(MinMemoryPolicy)
        expect_validator(AppMaxInstanceMemoryPolicy)
        expect_validator(InstancesPolicy)
        expect_validator(HealthCheckPolicy)
        expect_validator(CustomBuildpackPolicy)
        expect_validator(DockerPolicy)
      end

      describe 'org and space quota validator policies' do
        subject(:app) { AppFactory.make(space: space) }
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
        it 'does allow nil value' do
          expect {
            AppFactory.make(buildpack: nil)
          }.to_not raise_error
        end

        context 'when custom buildpacks are enabled' do
          it 'does allow a public url' do
            expect {
              AppFactory.make(buildpack: 'git://user@github.com:repo')
            }.to_not raise_error
          end

          it 'allows a public http url' do
            expect {
              AppFactory.make(buildpack: 'http://example.com/foo')
            }.to_not raise_error
          end

          it 'allows a buildpack name' do
            admin_buildpack = VCAP::CloudController::Buildpack.make
            app = nil
            expect {
              app = AppFactory.make(buildpack: admin_buildpack.name)
            }.to_not raise_error

            expect(app.admin_buildpack).to eql(admin_buildpack)
          end
        end

        context 'when custom buildpacks are disabled and the buildpack attribute is being changed' do
          before { disable_custom_buildpacks }

          it 'does NOT allow a public git url' do
            expect {
              AppFactory.make(buildpack: 'git://user@github.com:repo')
            }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
          end

          it 'does NOT allow a public http url' do
            expect {
              AppFactory.make(buildpack: 'http://example.com/foo')
            }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
          end

          it 'does allow a buildpack name' do
            admin_buildpack = VCAP::CloudController::Buildpack.make
            app = nil
            expect {
              app = AppFactory.make(buildpack: admin_buildpack.name)
            }.to_not raise_error

            expect(app.admin_buildpack).to eql(admin_buildpack)
          end

          it 'does not allow a private git url' do
            expect {
              AppFactory.make(buildpack: 'git@example.com:foo.git')
            }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
          end

          it 'does not allow a private git url with ssh schema' do
            expect {
              AppFactory.make(buildpack: 'ssh://git@example.com:foo.git')
            }.to raise_error(Sequel::ValidationFailed, /custom buildpacks are disabled/)
          end
        end

        context 'when custom buildpacks are disabled after app creation' do
          it 'permits the change even though the buildpack is still custom' do
            app = AppFactory.make(buildpack: 'git://user@github.com:repo')

            disable_custom_buildpacks

            expect {
              app.instances = 2
              app.save
            }.to_not raise_error
          end
        end

        it 'does not allow a non-url string' do
          expect {
            AppFactory.make(buildpack: 'Hello, world!')
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

      describe 'name' do
        let(:space) { Space.make }

        it 'does not allow the same name in a different case' do
          AppFactory.make(name: 'lowercase', space: space)

          expect {
            AppFactory.make(name: 'lowerCase', space: space)
          }.to raise_error(Sequel::ValidationFailed, /space_id and name/)
        end

        it 'should allow standard ascii characters' do
          app.name = "A -_- word 2!?()\'\"&+."
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          app.name = 'a \\ word'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          app.name = '防御力¡'
          expect {
            app.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          app.name = "a \n word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          app.name = "a \e word"
          expect {
            app.save
          }.to raise_error(Sequel::ValidationFailed)
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
          let(:space) { Space.make(organization: org, space_quota_definition: space_quota) }
          subject!(:app) { AppFactory.make(space: space, memory: 64, instances: 2, state: 'STARTED', package_hash: 'a-hash') }

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
            quota.memory_limit = 512
            quota.save

            app.instances = 5
            expect { app.save }.to raise_error(/instance_limit_exceeded/)
          end

          it 'should raise error when space instance quota is exceeded' do
            space_quota.app_instance_limit = 4
            space_quota.memory_limit = 512
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
            app.update(state: 'STARTED',
                       package_hash: 'abc',
                       package_state: 'STAGED',
                       droplet_hash: 'def')

            org.quota_definition = QuotaDefinition.make(memory_limit: 72)
            act_as_cf_admin { org.save }

            app.reload
            app.state = 'STOPPED'

            app.save

            app.reload
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
                  'docker_user' => 'user',
                  'docker_password' => 'password',
                  'docker_email' => 'email',
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
      let(:space) { Space.make }
      subject(:app) { App.new(space: space) }

      context 'when in a space in a suspended organization' do
        before { allow(space).to receive(:in_suspended_org?).and_return(true) }
        it 'is true' do
          expect(app).to be_in_suspended_org
        end
      end

      context 'when in a space in an unsuspended organization' do
        before { allow(space).to receive(:in_suspended_org?).and_return(false) }
        it 'is false' do
          expect(app).not_to be_in_suspended_org
        end
      end
    end

    describe '#stack' do
      def self.it_always_sets_stack
        context 'when stack was already set' do
          let(:stack) { Stack.make }
          before { subject.stack = stack }

          it 'keeps previously set stack' do
            subject.save
            subject.refresh
            expect(subject.stack).to eq(stack)
          end
        end

        context 'when stack was set to nil' do
          before do
            subject.stack = nil
            expect(Stack.default).not_to be_nil
          end

          it 'is populated with default stack' do
            subject.save
            subject.refresh
            expect(subject.stack).to eq(Stack.default)
          end
        end
      end

      context 'when app is being created' do
        subject do
          App.new(
            name: Sham.name,
            space: space,
          )
        end
        it_always_sets_stack
      end

      context 'when app is being updated' do
        subject { AppFactory.make }
        it_always_sets_stack
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

    describe '#stack=' do
      let(:new_stack) { Stack.make }

      context 'app was not staged before' do
        subject { App.new }

        it "doesn't mark the app for staging" do
          subject.stack = new_stack
          expect(subject.staged?).to be false
          expect(subject.needs_staging?).to be nil
        end
      end

      context 'app needs staging' do
        subject { AppFactory.make(
          package_hash: 'package-hash',
          package_state: 'PENDING',
          instances: 1,
          state: 'STARTED'
        )
        }

        it 'keeps app as needs staging' do
          subject.stack = new_stack
          expect(subject.staged?).to be false
          expect(subject.needs_staging?).to be true
        end
      end

      context 'app is already staged' do
        subject do
          AppFactory.make(
            package_hash: 'package-hash',
            instances: 1,
            droplet_hash: 'droplet-hash',
            package_state: 'STAGED',
            state: 'STARTED')
        end

        it 'marks the app for re-staging' do
          expect {
            subject.stack = new_stack
          }.to change { subject.needs_staging? }.from(false).to(true)
        end

        it 'does not consider app as staged' do
          expect {
            subject.stack = new_stack
          }.to change { subject.staged? }.from(true).to(false)
        end
      end
    end

    describe 'current_droplet' do
      context 'app is already staged' do
        subject do
          AppFactory.make(
            package_hash: 'package-hash',
            instances: 1,
            package_state: 'STAGED',
            droplet_hash: 'droplet-hash')
        end

        it 'knows its current droplet' do
          expect(subject.current_droplet).to be_instance_of(Droplet)
          expect(subject.current_droplet.droplet_hash).to eq('droplet-hash')

          new_droplet_hash = 'new droplet hash'
          subject.add_new_droplet(new_droplet_hash)
          expect(subject.reload.current_droplet.droplet_hash).to eq(new_droplet_hash)
        end

        context 'When it does not have a row in droplets table but has droplet hash column', droplet_cleanup: true do
          before do
            subject.droplet_hash = 'A-hash'
            subject.save
            subject.droplets_dataset.destroy
          end

          it 'knows its current droplet and persists it to the database' do
            expect(subject.current_droplet).to be_instance_of(Droplet)
            expect(subject.current_droplet.droplet_hash).to eq('A-hash')
            expect(Droplet.find(droplet_hash: 'A-hash')).not_to be_nil
          end
        end

        context 'When the droplet hash is nil' do
          it 'should return nul' do
            app_without_droplet = AppFactory.make(droplet_hash: nil)
            expect(app_without_droplet.current_droplet).to be_nil
          end
        end
      end
    end

    describe '#execution_metadata' do
      subject do
        App.make(
          package_hash: 'package-hash',
          instances: 1,
          package_state: 'STAGED',
        )
      end

      context 'v2' do
        context 'when the app has a current droplet' do
          before do
            subject.add_droplet(Droplet.new(
                                  app: subject,
                                  droplet_hash: 'the-droplet-hash',
                                  execution_metadata: 'some-staging-metadata',
            ))
            subject.droplet_hash = 'the-droplet-hash'
          end

          it "returns that droplet's staging metadata" do
            expect(subject.execution_metadata).to eq('some-staging-metadata')
          end
        end

        context 'when the app does not have a current droplet' do
          it 'returns the empty string' do
            expect(subject.current_droplet).to be_nil
            expect(subject.execution_metadata).to eq('')
          end
        end
      end

      context 'v3' do
        let(:v3_app) { AppModel.make }
        let(:v2_app) do
          App.make(
            package_hash: 'package-hash',
            instances: 1,
            package_state: 'STAGED',
            app_guid: v3_app.guid
          )
        end

        context 'when the app has a current droplet' do
          let(:v3_droplet) do
            DropletModel.make(
              app_guid: v3_app.guid,
              execution_metadata: 'some-other-metadata',
              state: VCAP::CloudController::DropletModel::STAGED_STATE
            )
          end

          before do
            v3_app.droplet = v3_droplet
            v3_app.save
          end

          it "returns that droplet's staging metadata" do
            expect(v2_app.execution_metadata).to eq(v3_droplet.execution_metadata)
          end
        end

        context 'when the app does not have a current droplet' do
          it 'returns nil' do
            expect(v2_app.current_droplet).to be_nil
            expect(v2_app.execution_metadata).to be_nil
          end
        end
      end
    end

    describe '#detected_start_command' do
      subject do
        App.make(
          package_hash: 'package-hash',
          instances: 1,
          package_state: 'STAGED',
        )
      end

      context 'when the app has a current droplet' do
        before do
          subject.add_droplet(Droplet.new(
                                app: subject,
                                droplet_hash: 'the-droplet-hash',
                                detected_start_command: 'run-my-app',
          ))
          subject.droplet_hash = 'the-droplet-hash'
        end

        it "returns that droplet's detected start command" do
          expect(subject.detected_start_command).to eq('run-my-app')
        end
      end

      context 'when the app does not have a current droplet' do
        it 'returns the empty string' do
          expect(subject.current_droplet).to be_nil
          expect(subject.detected_start_command).to eq('')
        end
      end
    end

    describe 'bad relationships' do
      context 'when changing space' do
        it 'is allowed if there are no space related associations' do
          app = AppFactory.make
          expect { app.space = Space.make }.not_to raise_error
        end

        it 'should fail if routes do not exist in that spaces' do
          app = AppFactory.make
          app.add_route(Route.make(space: app.space))
          expect { app.space = Space.make }.to raise_error Errors::InvalidRouteRelation
        end

        it 'should fail if service bindings do not exist in that space' do
          app = ServiceBinding.make.app
          expect { app.space = Space.make }.to raise_error ServiceBinding::InvalidAppAndServiceRelation
        end
      end

      it 'should not associate an app with a route created on another space with a shared domain' do
        shared_domain = SharedDomain.make
        app = AppFactory.make

        other_space = Space.make(organization: app.space.organization)
        route = Route.make(
          host: Sham.host,
          space: other_space,
          domain: shared_domain
        )

        expect {
          app.add_route(route)
        }.to raise_error Errors::InvalidRouteRelation
      end
    end

    describe '#environment_json' do
      it 'deserializes the serialized value' do
        app = AppFactory.make(environment_json: { 'jesse' => 'awesome' })
        expect(app.environment_json).to eq('jesse' => 'awesome')
      end

      def self.it_does_not_mark_for_re_staging
        it 'does not mark an app for restage' do
          app = AppFactory.make(
            package_hash: 'deadbeef',
            package_state: 'STAGED',
            environment_json: old_env_json,
          )

          expect {
            app.environment_json = new_env_json
            app.save
          }.to_not change { app.needs_staging? }
        end
      end

      context 'if env changes' do
        let(:old_env_json) { {} }
        let(:new_env_json) { { 'key' => 'value' } }
        it_does_not_mark_for_re_staging
      end

      context 'if BUNDLE_WITHOUT in env changes' do
        let(:old_env_json) { { 'BUNDLE_WITHOUT' => 'test' } }
        let(:new_env_json) { { 'BUNDLE_WITHOUT' => 'development' } }
        it_does_not_mark_for_re_staging
      end

      describe 'env is encrypted' do
        let(:env) { { 'jesse' => 'awesome' } }
        let(:long_env) { { 'many_os' => 'o' * 10_000 } }
        let!(:app) { AppFactory.make(environment_json: env) }
        let(:last_row) { VCAP::CloudController::App.dataset.naked.order_by(:id).last }

        it 'is encrypted' do
          expect(last_row[:encrypted_environment_json]).not_to eq MultiJson.dump(env).to_s
        end

        it 'is decrypted' do
          app.reload
          expect(app.environment_json).to eq env
        end

        it 'does not store unecrypted environment json' do
          expect(last_row[:environment_json]).to be_nil
        end

        it 'salt is unique for each app' do
          app_2 = AppFactory.make(environment_json: env)
          expect(app.salt).not_to eq app_2.salt
        end

        it 'must have a salt of length 8' do
          expect(app.salt.length).to eq 8
        end

        it 'must deal with null env_json to remain null after encryption' do
          null_json_app = AppFactory.make
          expect(null_json_app.environment_json).to be_nil
        end

        it 'works with long serialized environments' do
          app = AppFactory.make(environment_json: long_env)
          app.reload
          expect(app.environment_json).to eq(long_env)
        end
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
          docker_user: user,
          docker_password: password,
          docker_email: email
        }
      end
      let(:expected_docker_credentials) do
        {
          'docker_login_server' => login_server,
          'docker_user' => user,
          'docker_password' => password,
          'docker_email' => email
        }
      end

      describe 'serialization' do
        let(:app) do
          AppFactory.make(docker_credentials_json: docker_credentials)
        end

        it 'deserializes the serialized value' do
          expect(app.docker_credentials_json).to eq(expected_docker_credentials)
        end
      end

      describe 'restage' do
        context 'if credentials change' do
          let(:new_credentials) do
            {
              docker_login_server: login_server,
              docker_user: user,
              docker_password: password,
              docker_email: email
            }
          end
          let(:app) do
            AppFactory.make(
              package_hash: 'deadbeef',
              package_state: 'STAGED',
              docker_credentials_json: docker_credentials,
            )
          end

          it 'does not mark an app for restage' do
            expect {
              app.docker_credentials_json = new_credentials
              app.save
            }.not_to change { app.needs_staging? }
          end
        end
      end

      describe 'encryption' do
        let!(:app) do
          AppFactory.make(docker_credentials_json: docker_credentials)
        end
        let(:last_row) { VCAP::CloudController::App.dataset.naked.order_by(:id).last }

        it 'is encrypted' do
          expect(last_row[:encrypted_docker_credentials_json]).not_to eq docker_credentials
        end

        it 'is decrypted' do
          app.reload
          expect(app.docker_credentials_json).to eq expected_docker_credentials
        end

        it 'does not store unecrypted credentials' do
          expect(last_row[:docker_credentials_json]).to be_nil
        end

        it 'docker_salt is unique for each app' do
          app_2 = AppFactory.make(docker_credentials_json: docker_credentials)
          expect(app.docker_salt).not_to eq app_2.docker_salt
        end

        it 'must have a docker_salt of length 8' do
          expect(app.docker_salt.length).to eq 8
        end

        it 'must deal with null credentials to remain null after encryption' do
          null_credentials_app = AppFactory.make
          expect(null_credentials_app.docker_credentials_json).to be_nil
        end
      end
    end

    describe '#database_uri' do
      let(:space) { Space.make }
      let(:app) { App.make(environment_json: { 'jesse' => 'awesome' }, space: space) }

      context 'when there are database-like services' do
        before do
          sql_service_plan = ServicePlan.make(service: Service.make(label: 'elephantsql-n/a'))
          sql_service_instance = ManagedServiceInstance.make(space: space, service_plan: sql_service_plan, name: 'elephantsql-vip-uat')
          ServiceBinding.make(app: app, service_instance: sql_service_instance, credentials: { 'uri' => 'mysql://foo.com' })

          banana_service_plan = ServicePlan.make(service: Service.make(label: 'chiquita-n/a'))
          banana_service_instance = ManagedServiceInstance.make(space: space, service_plan: banana_service_plan, name: 'chiqiuta-yummy')
          ServiceBinding.make(app: app, service_instance: banana_service_instance, credentials: { 'uri' => 'banana://yum.com' })
        end

        it 'returns database uri' do
          expect(app.database_uri).to eq('mysql2://foo.com')
        end
      end

      context 'when there are non-database-like services' do
        before do
          banana_service_plan = ServicePlan.make(service: Service.make(label: 'chiquita-n/a'))
          banana_service_instance = ManagedServiceInstance.make(space: space, service_plan: banana_service_plan, name: 'chiqiuta-yummy')
          ServiceBinding.make(app: app, service_instance: banana_service_instance, credentials: { 'uri' => 'banana://yum.com' })

          uncredentialed_service_plan = ServicePlan.make(service: Service.make(label: 'mysterious-n/a'))
          uncredentialed_service_instance = ManagedServiceInstance.make(space: space, service_plan: uncredentialed_service_plan, name: 'mysterious-mystery')
          ServiceBinding.make(app: app, service_instance: uncredentialed_service_instance, credentials: {})
        end

        it 'returns nil' do
          expect(app.database_uri).to be_nil
        end
      end

      context 'when there are no services' do
        it 'returns nil' do
          expect(app.database_uri).to be_nil
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
        app = AppFactory.make(command: 'echo hi')
        app.command = ''
        app.save
        app.refresh
        expect(app.command).to eq(nil)
      end

      it 'saves the field as nil when set to nil' do
        app = AppFactory.make(command: 'echo hi')
        app.command = nil
        app.save
        app.refresh
        expect(app.command).to eq(nil)
      end

      it 'falls back to metadata value if command is not present' do
        app = AppFactory.make(metadata: { command: 'echo hi' })
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

    describe 'update_detected_buildpack' do
      let(:app) { AppFactory.make }
      let(:detect_output) { 'buildpack detect script output' }

      context 'when detect output is available' do
        it 'sets detected_buildpack with the output of the detect script' do
          app.update_detected_buildpack(detect_output, nil)
          expect(app.detected_buildpack).to eq(detect_output)
        end
      end

      context 'when an admin buildpack is used for staging' do
        let(:admin_buildpack) { Buildpack.make }
        before do
          app.buildpack = admin_buildpack.name
        end

        it 'sets the buildpack guid of the buildpack used to stage when present' do
          app.update_detected_buildpack(detect_output, admin_buildpack.key)
          expect(app.detected_buildpack_guid).to eq(admin_buildpack.guid)
        end

        it 'sets the buildpack name to the admin buildpack used to stage' do
          app.update_detected_buildpack(detect_output, admin_buildpack.key)
          expect(app.detected_buildpack_name).to eq(admin_buildpack.name)
        end
      end

      context 'when the buildpack key is missing (custom buildpack used)' do
        let(:custom_buildpack_url) { 'https://example.com/repo.git' }
        before do
          app.buildpack = custom_buildpack_url
        end

        it 'sets the buildpack name to the custom buildpack url when a buildpack key is missing' do
          app.update_detected_buildpack(detect_output, nil)
          expect(app.detected_buildpack_name).to eq(custom_buildpack_url)
        end

        it 'sets the buildpack guid to nil' do
          app.update_detected_buildpack(detect_output, nil)
          expect(app.detected_buildpack_guid).to be_nil
        end
      end

      context 'when staging has completed' do
        context 'and the app state remains STARTED' do
          it 'creates an app usage event with BUILDPACK_SET as the state' do
            app = AppFactory.make(package_hash: 'abc', state: 'STARTED', package_state: 'STAGED')
            expect {
              app.update_detected_buildpack(detect_output, nil)
            }.to change { AppUsageEvent.count }.by(1)
            event = AppUsageEvent.last

            expect(event.state).to eq('BUILDPACK_SET')
            event.state = 'STARTED'
            expect(event).to match_app(app)
          end
        end

        context 'and the app state is no longer STARTED' do
          it 'does ont create an app usage event' do
            app = AppFactory.make(package_hash: 'abc', state: 'STOPPED')
            expect {
              app.update_detected_buildpack(detect_output, nil)
            }.to_not change { AppUsageEvent.count }
          end
        end
      end
    end

    describe 'buildpack=' do
      let(:valid_git_url) do
        'git://user@github.com:repo'
      end
      it 'can be set to a git url' do
        app = App.new
        app.buildpack = valid_git_url
        expect(app.buildpack).to eql CustomBuildpack.new(valid_git_url)
      end

      it 'can be set to a buildpack name' do
        buildpack = Buildpack.make
        app = App.new
        app.buildpack = buildpack.name
        expect(app.buildpack).to eql(buildpack)
      end

      it 'can be set to empty string' do
        app = App.new
        app.buildpack = ''
        expect(app.buildpack).to eql(nil)
      end

      context 'switching between buildpacks' do
        it 'allows changing from admin buildpacks to a git url' do
          buildpack = Buildpack.make
          app = App.new(buildpack: buildpack.name)
          app.buildpack = valid_git_url
          expect(app.buildpack).to eql(CustomBuildpack.new(valid_git_url))
        end

        it 'allows changing from git url to admin buildpack' do
          buildpack = Buildpack.make
          app = App.new(buildpack: valid_git_url)
          app.buildpack = buildpack.name
          expect(app.buildpack).to eql(buildpack)
        end
      end
    end

    describe 'custom_buildpack_url' do
      context 'when a custom buildpack is associated with the app' do
        it 'should be the custom url' do
          app = App.make(buildpack: 'https://example.com/repo.git')
          expect(app.custom_buildpack_url).to eq('https://example.com/repo.git')
        end
      end

      context 'when an admin buildpack is associated with the app' do
        it 'should be nil' do
          app = App.make
          app.admin_buildpack = Buildpack.make
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

    describe 'package_hash=' do
      let(:app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }

      it 'should set the state to PENDING if the hash changes' do
        app.package_hash = 'def'
        expect(app.package_state).to eq('PENDING')
        expect(app.package_hash).to eq('def')
      end

      it 'should set the package updated at to the current date' do
        app.package_updated_at = nil
        expect {
          app.package_hash = 'def'
        }.to change { app.package_updated_at }
        expect(app.package_hash).to_not be_nil
      end

      it 'should not set the state to PENDING if the hash remains the same' do
        app.package_hash = 'abc'
        expect(app.package_state).to eq('STAGED')
        expect(app.package_hash).to eq('abc')
      end
    end

    describe 'staged?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is STAGED' do
        app.package_state = 'STAGED'
        expect(app.staged?).to be true
      end

      it 'should return false if package_state is PENDING' do
        app.package_state = 'PENDING'
        expect(app.staged?).to be false
      end
    end

    describe 'pending?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is PENDING' do
        app.package_state = 'PENDING'
        expect(app.pending?).to be true
      end

      it 'should return false if package_state is not PENDING' do
        app.package_state = 'STARTED'
        expect(app.pending?).to be false
      end
    end

    describe 'staging?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is PENDING and staging_task_id is not null' do
        app.package_state = 'PENDING'
        app.staging_task_id = 'some-non-null-value'
        expect(app.staging?).to be true
      end

      it 'should return false if package_state is not PENDING' do
        app.package_state = 'STARTED'
        app.staging_task_id = 'some-non-null-value'
        expect(app.staging?).to be false
      end

      it 'should return false if staging_task_id is empty' do
        app.package_state = 'PENDING'
        expect(app.staging?).to be false
      end
    end

    describe 'failed?' do
      let(:app) { AppFactory.make }

      it 'should return true if package_state is FAILED' do
        app.package_state = 'FAILED'
        expect(app.staging_failed?).to be true
      end

      it 'should return false if package_state is not FAILED' do
        app.package_state = 'STARTED'
        expect(app.staging_failed?).to be false
      end
    end

    describe 'needs_staging?' do
      subject(:app) { AppFactory.make }

      context 'when the app is started' do
        before do
          app.state = 'STARTED'
          app.instances = 1
        end

        it 'should return false if the package_hash is nil' do
          app.package_hash = nil
          expect(app.needs_staging?).to be nil
        end

        it 'should return true if PENDING is set' do
          app.package_hash = 'abc'
          app.package_state = 'PENDING'
          expect(app.needs_staging?).to be true
        end

        it 'should return false if STAGING is set' do
          app.package_hash = 'abc'
          app.package_state = 'STAGED'
          expect(app.needs_staging?).to be false
        end
      end

      context 'when the app is not started' do
        before do
          app.state = 'STOPPED'
          app.package_hash = 'abc'
          app.package_state = 'PENDING'
        end

        it 'should return false' do
          expect(app).not_to be_needs_staging
        end
      end

      context 'when the app has no instances' do
        before do
          app.state = 'STARTED'
          app.package_hash = 'abc'
          app.package_state = 'PENDING'
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
      let(:app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED') }

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

        context 'when adding and removing routes' do
          let(:domain) do
            PrivateDomain.make owning_organization: app.space.organization
          end

          let(:route) { Route.make domain: domain, space: app.space }

          it "updates the app's version" do
            expect { app.add_route(route) }.to change(app, :version)
            expect { app.remove_route(route) }.to change(app, :version)
          end

          context 'audit events' do
            let(:app_event_repository) { Repositories::Runtime::AppEventRepository.new }

            before do
              allow(Repositories::Runtime::AppEventRepository).to receive(:new).and_return(app_event_repository)
            end

            it 'creates audit events for both adding routes' do
              expect(app_event_repository).to receive(:record_map_route).ordered.and_call_original
              expect { app.add_route(route) }.to change { Event.count }.by(1)

              expect(app_event_repository).to receive(:record_unmap_route).ordered.and_call_original
              expect { app.remove_route(route) }.to change { Event.count }.by(1)
            end
          end
        end

        it 'should update the version when changing enable_ssh' do
          expect {
            app.update(enable_ssh: !app.enable_ssh)
          }.to change { app.version }
        end
      end
    end

    describe '#start!' do
      let!(:app) { AppFactory.make }

      before do
        allow(AppObserver).to receive(:updated)
      end

      it 'should set the state to started' do
        expect {
          app.start!
        }.to change { app.state }.to 'STARTED'
      end

      it 'saves the app to trigger the AppObserver', isolation: :truncation do
        expect(AppObserver).not_to have_received(:updated).with(app)
        app.start!
        expect(AppObserver).to have_received(:updated).with(app)
      end
    end

    describe '#stop!' do
      let!(:app) { AppFactory.make }

      before do
        allow(AppObserver).to receive(:updated)
        app.state = 'STARTED'
      end

      it 'sets the state to stopped' do
        expect {
          app.stop!
        }.to change { app.state }.to 'STOPPED'
      end

      it 'saves the app to trigger the AppObserver', isolation: :truncation do
        expect(AppObserver).not_to have_received(:updated).with(app)
        app.stop!
        expect(AppObserver).to have_received(:updated).with(app)
      end
    end

    describe '#mark_as_staged' do
      let(:app) { AppFactory.make }

      it 'resets the package_pending_since timestamp' do
        expect {
          app.mark_as_staged
        }.to change { app.package_pending_since }.from(kind_of(Time)).to(nil)
      end
    end

    describe '#mark_as_failed_to_stage' do
      let(:app) { AppFactory.make(state: 'STARTED') }

      it 'should set the package state to failed' do
        expect {
          app.mark_as_failed_to_stage
        }.to change { app.package_state }.to 'FAILED'
      end

      it 'resets the package_pending_since timestamp' do
        expect {
          app.mark_as_failed_to_stage
        }.to change { app.package_pending_since }.from(kind_of(Time)).to(nil)
      end

      describe 'setting staging_failed_description' do
        it 'sets the staging_failed_description to the v2.yml description of the error type' do
          expect {
            app.mark_as_failed_to_stage('NoAppDetectedError')
          }.to change { app.staging_failed_description }.to('An app was not successfully detected by any available buildpack')
        end

        it 'provides a string for interpolation on errors that require it' do
          expect {
            app.mark_as_failed_to_stage('StagingError')
          }.to change { app.staging_failed_description }.to('Staging error: staging failed')
        end

        App::STAGING_FAILED_REASONS.each do |reason|
          it "successfully sets staging_failed_description for reason: #{reason}" do
            expect {
              app.mark_as_failed_to_stage(reason)
            }.to_not raise_error
          end
        end
      end

      context 'when a valid reason is specified' do
        App::STAGING_FAILED_REASONS.each do |reason|
          it 'sets the requested staging failed reason' do
            expect {
              app.mark_as_failed_to_stage(reason)
            }.to change { app.staging_failed_reason }.to(reason)
          end
        end
      end

      context 'when an unexpected reason is specifed' do
        it 'should use the default, generic reason' do
          expect {
            app.mark_as_failed_to_stage
          }.to change { app.staging_failed_reason }.to 'StagingError'
        end
      end

      context 'when a reason is not specified' do
        it 'should use the default, generic reason' do
          expect {
            app.mark_as_failed_to_stage
          }.to change { app.staging_failed_reason }.to 'StagingError'
        end
      end

      context 'when the app is a dea app' do
        it 'does not change the app state' do
          expect {
            app.mark_as_failed_to_stage
          }.to_not change { app.state }
        end
      end

      context 'when the app is a diego app' do
        before do
          app.update(diego: true)
        end

        it 'should mark the app as stopped' do
          expect {
            app.mark_as_failed_to_stage
          }.to change { app.state }.from('STARTED').to('STOPPED')
        end
      end
    end

    describe '#mark_for_restaging' do
      let(:app) { AppFactory.make }

      before do
        app.package_state = 'FAILED'
        app.staging_failed_reason = 'StagingError'
        app.staging_failed_description = 'Failed to stage because of something very tragic'
      end

      it 'should set the package state pending' do
        expect {
          app.mark_for_restaging
        }.to change { app.package_state }.to 'PENDING'
      end

      it 'should clear the staging failed reason' do
        expect {
          app.mark_for_restaging
        }.to change { app.staging_failed_reason }.to nil
      end

      it 'should clear the staging failed description' do
        expect {
          app.mark_for_restaging
        }.to change { app.staging_failed_description }.to nil
      end

      it 'updates the package_pending_since date to current' do
        app.package_pending_since = nil
        app.save
        expect {
          app.mark_for_restaging
          app.save
        }.to change { app.reload.package_pending_since }.from(nil).to(kind_of(Time))
      end
    end

    describe '#restage!' do
      let(:app) { AppFactory.make }

      it 'stops the app, marks the app for restaging, and starts the app', isolation: :truncation do
        @updated_apps = []
        allow(AppObserver).to receive(:updated) do |app|
          @updated_apps << app
        end
        expect(AppObserver).not_to have_received(:updated)
        app.restage!
        expect(@updated_apps.first.state).to eq('STOPPED')
        expect(@updated_apps.last.package_state).to eq('PENDING')
        expect(@updated_apps.last.state).to eq('STARTED')
      end
    end

    describe '#desired_instances' do
      before do
        @app = App.new
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
        app = AppFactory.make(space: space)
        domain = PrivateDomain.make(name: 'mydomain.com', owning_organization: org)
        route = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
        app.add_route(route)
        expect(app.uris).to eq(['myhost.mydomain.com/my%20path'])
      end
    end

    describe 'routing_info' do
      let(:domain) { PrivateDomain.make(name: 'mydomain.com', owning_organization: org) }
      let(:app) { AppFactory.make(space: space, diego: true) }
      let(:route_without_service) { Route.make(host: 'host2', domain: domain, space: space, path: '/my%20path') }
      let(:route_with_service) do
        route = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
        service_instance = ManagedServiceInstance.make(:routing, space: space)
        RouteBinding.make(route: route, service_instance: service_instance)
        route
      end

      context 'with no app ports specified' do
        before do
          app.add_route(route_with_service)
          app.add_route(route_without_service)
        end

        it 'returns the mapped http routes associated with the app' do
          expected_http = [
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
            { 'hostname' => route_without_service.uri, 'port' => 8080 }
          ]

          expect(app.routing_info.keys).to match_array ['http_routes']
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end

      context 'with app port specified in route mapping' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
        let!(:route_mapping) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

        it 'returns the app port in routing info' do
          expected_http = [
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
          ]

          expect(app.routing_info.keys).to match_array ['http_routes']
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end

      context 'with multiple route mapping to same route with different app ports' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
        let!(:route_mapping1) { RouteMapping.make(app: app, route: route_with_service, app_port: 8080) }
        let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

        it 'returns the app port in routing info' do
          expected_http = [
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
          ]

          expect(app.routing_info.keys).to match_array ['http_routes']
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end

      context 'with multiple route mapping to different route with same app port' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
        let!(:route_mapping1) { RouteMapping.make(app: app, route: route_without_service, app_port: 9090) }
        let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

        it 'returns the app port in routing info' do
          expected_http = [
            { 'hostname' => route_without_service.uri, 'port' => 9090 },
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
          ]

          expect(app.routing_info.keys).to match_array ['http_routes']
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end

      context 'with multiple route mapping to different route with different app ports' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090]) }
        let!(:route_mapping1) { RouteMapping.make(app: app, route: route_without_service, app_port: 8080) }
        let!(:route_mapping2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }

        it 'returns the app port in routing info' do
          expected_http = [
            { 'hostname' => route_without_service.uri, 'port' => 8080 },
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
          ]
          expect(app.routing_info.keys).to match_array ['http_routes']
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end

      context 'tcp routes' do
        context 'with only one app port mapped to route' do
          let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
          let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
          let(:tcp_route) { Route.make(domain: domain, space: space, port: 52000) }
          let!(:route_mapping) { RouteMapping.make(app: app, route: tcp_route, app_port: 9090) }

          it 'returns the app port in routing info' do
            expected_tcp = [
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
            ]

            expect(app.routing_info.keys).to match_array ['tcp_routes']
            expect(app.routing_info['tcp_routes']).to match_array expected_tcp
          end
        end

        context 'with multiple app ports mapped to same route' do
          let(:app) { AppFactory.make(space: space, diego: true, ports: [9090, 5555]) }
          let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
          let(:tcp_route) { Route.make(domain: domain, space: space, port: 52000) }
          let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route, app_port: 9090) }
          let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route, app_port: 5555) }

          it 'returns the app ports in routing info' do
            expected_tcp = [
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 9090 },
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
            ]

            expect(app.routing_info.keys).to match_array ['tcp_routes']
            expect(app.routing_info['tcp_routes']).to match_array expected_tcp
          end
        end

        context 'with same app port mapped to different routes' do
          let(:app) { AppFactory.make(space: space, diego: true, ports: [9090]) }
          let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
          let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
          let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
          let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route_1, app_port: 9090) }
          let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route_2, app_port: 9090) }

          it 'returns the app ports in routing info' do
            expected_routes = [
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 9090 },
            ]

            expect(app.routing_info.keys).to match_array ['tcp_routes']
            expect(app.routing_info['tcp_routes']).to match_array expected_routes
          end
        end

        context 'with different app ports mapped to different routes' do
          let(:app) { AppFactory.make(space: space, diego: true, ports: [9090, 5555]) }
          let(:domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
          let(:tcp_route_1) { Route.make(domain: domain, space: space, port: 52000) }
          let(:tcp_route_2) { Route.make(domain: domain, space: space, port: 52001) }
          let!(:route_mapping_1) { RouteMapping.make(app: app, route: tcp_route_1, app_port: 9090) }
          let!(:route_mapping_2) { RouteMapping.make(app: app, route: tcp_route_2, app_port: 5555) }

          it 'returns the multiple route mappings in routing info' do
            expected_routes = [
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_1.port, 'container_port' => 9090 },
              { 'router_group_guid' => domain.router_group_guid, 'external_port' => tcp_route_2.port, 'container_port' => 5555 },
            ]

            expect(app.routing_info.keys).to match_array ['tcp_routes']
            expect(app.routing_info['tcp_routes']).to match_array expected_routes
          end
        end
      end

      context 'with both http and tcp routes' do
        let(:app) { AppFactory.make(space: space, diego: true, ports: [8080, 9090, 5555]) }
        let(:tcp_domain) { SharedDomain.make(name: 'tcpdomain.com', router_group_guid: 'router-group-guid-1') }
        let(:tcp_route) { Route.make(domain: tcp_domain, space: space, port: 52000) }
        let!(:route_mapping_1) { RouteMapping.make(app: app, route: route_with_service, app_port: 8080) }
        let!(:route_mapping_2) { RouteMapping.make(app: app, route: route_with_service, app_port: 9090) }
        let!(:tcp_route_mapping) { RouteMapping.make(app: app, route: tcp_route, app_port: 5555) }

        it 'returns the app port in routing info' do
          expected_http = [
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 8080 },
            { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_service_url, 'port' => 9090 },
          ]

          expected_tcp = [
            { 'router_group_guid' => tcp_domain.router_group_guid, 'external_port' => tcp_route.port, 'container_port' => 5555 },
          ]

          expect(app.routing_info.keys).to match_array ['tcp_routes', 'http_routes']
          expect(app.routing_info['tcp_routes']).to match_array expected_tcp
          expect(app.routing_info['http_routes']).to match_array expected_http
        end
      end
    end

    describe '#validate_route' do
      it 'should not associate an app with a route on a different space' do
        app = AppFactory.make

        domain = PrivateDomain.make(
          owning_organization: app.space.organization
        )

        other_space = Space.make(organization: app.space.organization)

        route = Route.make(
          space: other_space,
          domain: domain,
        )

        expect {
          app.add_route(route)
        }.to raise_error(Errors::InvalidRouteRelation, /The requested route relation is invalid/)
      end

      context 'adding routes to unsaved apps' do
        it 'should set a route by guid on a new but unsaved app' do
          app = App.new(name: Sham.name,
                        space: space,
                        stack: Stack.make)
          app.add_route_by_guid(route.guid)
          app.save
          expect(app.routes).to eq([route])
        end

        it 'should not allow a route on a domain from another org' do
          app = App.new(name: Sham.name,
                        space: space,
                        stack: Stack.make)
          app.add_route_by_guid(Route.make.guid)
          expect { app.save }.to raise_error(Errors::InvalidRouteRelation)
          expect(app.routes).to be_empty
        end
      end

      context 'when the route is bound to a routing service' do
        let(:domain) { PrivateDomain.make(name: 'mydomain.com', owning_organization: org) }
        let(:app) { AppFactory.make(space: space, diego: diego?) }
        let(:route_with_service) do
          route = Route.make(host: 'myhost', domain: domain, space: space, path: '/my%20path')
          service_instance = ManagedServiceInstance.make(:routing, space: space)
          RouteBinding.make(route: route, service_instance: service_instance)
          route
        end

        context 'and the app uses diego' do
          let(:diego?) { true }
          it 'does not raise an error' do
            expect {
              app.add_route_by_guid(route_with_service.guid)
              app.save
            }.not_to raise_error
          end
        end

        context 'and the app does not use diego' do
          let(:diego?) { false }
          it 'to raise error' do
            expect {
              app.add_route_by_guid(route_with_service.guid)
              app.save
            }.to raise_error(Errors::InvalidRouteRelation).
              with_message("The requested route relation is invalid: #{route_with_service.guid} - Route services are only supported for apps on Diego")
          end
        end
      end
    end

    describe 'creation' do
      it 'does not create an AppUsageEvent' do
        expect {
          App.create_from_hash(name: 'awesome app', space_guid: space.guid)
        }.not_to change { AppUsageEvent.count }
      end

      describe 'default enable_ssh' do
        context 'when enable_ssh is set explicitly' do
          it 'does not overwrite it with the default' do
            app1 = App.create_from_hash(name: 'awesome app 1', space_guid: space.guid, enable_ssh: true)
            expect(app1.enable_ssh).to eq(true)

            app2 = App.create_from_hash(name: 'awesome app 2', space_guid: space.guid, enable_ssh: false)
            expect(app2.enable_ssh).to eq(false)
          end
        end

        context 'when global allow_ssh config is true' do
          before do
            TestConfig.override({ allow_app_ssh_access: true })
          end

          context 'when space allow_ssh config is true' do
            before do
              space.update(allow_ssh: true)
            end

            it 'sets enable_ssh to true' do
              app = App.create_from_hash(name: 'awesome app', space_guid: space.guid)
              expect(app.enable_ssh).to eq(true)
            end
          end

          context 'when space allow_ssh config is false' do
            before do
              space.update(allow_ssh: false)
            end

            it 'sets enable_ssh to false' do
              app = App.create_from_hash(name: 'awesome app', space_guid: space.guid)
              expect(app.enable_ssh).to eq(false)
            end
          end
        end

        context 'when global allow_ssh config is false' do
          before do
            TestConfig.override({ allow_app_ssh_access: false })
          end

          it 'sets enable_ssh to false' do
            app = App.create_from_hash(name: 'awesome app', space_guid: space.guid)
            expect(app.enable_ssh).to eq(false)
          end
        end
      end

      describe 'default_app_memory' do
        before do
          TestConfig.override({ default_app_memory: 200 })
        end

        it 'uses the provided memory' do
          app = App.create_from_hash(name: 'awesome app', space_guid: space.guid, memory: 100)
          expect(app.memory).to eq(100)
        end

        it 'uses the default_app_memory when none is provided' do
          app = App.create_from_hash(name: 'awesome app', space_guid: space.guid)
          expect(app.memory).to eq(200)
        end
      end

      describe 'default disk_quota' do
        before do
          TestConfig.override({ default_app_disk_in_mb: 512 })
        end

        it 'should use the provided quota' do
          app = App.create_from_hash(name: 'test', space_guid: space.guid, disk_quota: 256)
          expect(app.disk_quota).to eq(256)
        end

        it 'should use the default quota' do
          app = App.create_from_hash(name: 'test', space_guid: space.guid)
          expect(app.disk_quota).to eq(512)
        end
      end

      describe 'instance_file_descriptor_limit' do
        before do
          TestConfig.override({ instance_file_descriptor_limit: 200 })
        end

        it 'uses the instance_file_descriptor_limit config variable' do
          app = App.create_from_hash(name: 'awesome app', space_guid: space.guid)
          expect(app.file_descriptors).to eq(200)
        end
      end

      describe 'default ports' do
        context 'with a diego app' do
          context 'and no ports are specified' do
            it 'has a default port value' do
              App.create_from_hash(name: 'test', space_guid: space.guid, diego: true)
              expect(App.last.ports).to eq [8080]
            end
          end

          context 'and ports are specified' do
            it 'uses the ports provided' do
              App.create_from_hash(name: 'test', space_guid: space.guid, diego: true, ports: [9999])
              expect(App.last.ports).to eq [9999]
            end
          end
        end
      end
    end

    describe 'updating' do
      context 'switching from diego to dea' do
        let(:app_hash) do
          {
            name: 'test',
            package_hash: 'abc',
            package_state: 'STAGED',
            state: 'STARTED',
            space_guid: space.guid,
            diego: true,
            ports: [8080, 2345]
          }
        end
        let(:app) { AppFactory.make(app_hash) }
        let(:route) { Route.make(host: 'host', space: app.space) }
        let(:route2) { Route.make(host: 'host', space: app.space) }
        let!(:route_mapping_1) { RouteMapping.make(app: app, route: route) }
        let!(:route_mapping_2) { RouteMapping.make(app: app, route: route2) }

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

        it 'should set route mappings app_port to nil' do
          app.save
          expect(route_mapping_1.reload.user_provided_app_port).to be_nil
          expect(route_mapping_1.reload.app_port).to be_nil
          expect(route_mapping_1.reload.user_provided_app_port).to be_nil
          expect(route_mapping_2.reload.app_port).to be_nil
        end

        context 'app with one or more routes and multiple ports' do
          before do
            route_mapping_2.app_port = 2345
          end

          it 'should add an error' do
            expect {
              app.save
            }.to raise_error Sequel::ValidationFailed, /Multiple app ports not allowed/
          end
        end
      end

      context 'switching from dea to diego' do
        let(:app) { App.create_from_hash(name: 'test', space_guid: space.guid, diego: false) }
        let(:route) { Route.make(host: 'host', space: space) }
        let!(:route_mapping) { RouteMapping.make(app: app, route: route) }

        context 'and no ports specified' do
          before do
            app.update_from_hash(diego: true)
          end

          it 'defaults to 8080' do
            expect(app.reload.ports).to eq [8080]
            app.route_mappings.each do |rm|
              expect(rm.user_provided_app_port).to be_nil
              expect(rm.app_port).to eq 8080
            end
          end
        end

        context 'and ports are specified' do
          before do
            app.update_from_hash(diego: true, ports: [2345, 1298])
          end

          it 'uses the ports provided' do
            expect(app.reload.ports).to eq [2345, 1298]
            app.route_mappings.each do |rm|
              expect(rm.user_provided_app_port).to eq 2345
              expect(rm.app_port).to eq 2345
            end
          end
        end

        context 'when using a docker app' do
          before do
            app.update_from_hash(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
            app.add_droplet(Droplet.new(
                              app: app,
                              droplet_hash: 'the-droplet-hash',
                              execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
            ))
            app.droplet_hash = 'the-droplet-hash'
            app.save
          end

          it 'does not save the app port' do
            expect(app.reload.ports).to eq [1024, 1025]
            app.route_mappings.each do |rm|
              expect(rm.user_provided_app_port).to be_nil
              expect(rm.app_port).to eq 1024
            end
          end
        end
      end

      context 'when changing ports from the default port' do
        let(:app) { AppFactory.make(diego: true) }
        let(:route) { Route.make(space: app.space) }

        before do
          RouteMapping.make(app: app, route: route)
        end

        it 'updates all route mappings associated with the app to the default port' do
          app.ports = [7777, 8080]

          expect {
            app.save
            app.reload
          }.to change { app.route_mappings.map(&:user_provided_app_port) }.from([nil]).to([8080])
        end
      end

      context 'when changing ports on a docker app' do
        let(:app) { App.make(diego: true, docker_image: 'some-docker-image', package_state: 'PENDING') }
        let(:route) { Route.make(space: app.space) }

        before do
          RouteMapping.make(app: app, route: route)
        end

        it 'does not change route mappings associated with the app' do
          app.ports = [7777, 8080]

          expect {
            app.save
            app.reload
          }.to_not change { app.route_mappings.map(&:user_provided_app_port) }
        end
      end

      context 'when updating user provided ports' do
        let(:app) { AppFactory.make(diego: true, ports: [7777, 8080]) }
        let(:route) { Route.make(space: app.space) }

        before do
          RouteMapping.make(app: app, route: route, app_port: 7777)
        end

        it 'does not update route mappings' do
          app.ports = [8888, 7777, 8080]

          expect {
            app.save
            app.reload
          }.to_not change { app.route_mappings.map(&:user_provided_app_port) }
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

            expect(AppObserver).to receive(:updated).once.with(app).and_raise Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty')
            expect(undo_app).to receive(:undo)
            expect { app.update(state: 'STARTED') }.to raise_error(Errors::ApiError, /app package hash/)
          end
        end

        context 'when the app is a diego app' do
          before do
            allow(UndoAppChanges).to receive(:new)
          end

          let(:app) { AppFactory.make(diego: true) }

          it 'does not call UndoAppChanges', isolation: :truncation do
            expect(AppObserver).to receive(:updated).once.with(app).and_raise Errors::ApiError.new_from_details('AppPackageInvalid', 'The app package hash is empty')
            expect { app.update(state: 'STARTED') }.to raise_error(Errors::ApiError, /app package hash/)
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
          app = AppFactory.make(package_hash: 'abc', state: 'STARTED')
          expect {
            app.update(state: 'STOPPED')
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end
      end

      context 'when app instances changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          app = AppFactory.make(package_hash: 'abc', state: 'STARTED')
          expect {
            app.update(instances: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          app = AppFactory.make(package_hash: 'abc', state: 'STOPPED')
          expect {
            app.update(instances: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when app memory changes' do
        it 'creates an AppUsageEvent when the app is STARTED' do
          app = AppFactory.make(package_hash: 'abc', state: 'STARTED')
          expect {
            app.update(memory: 2)
          }.to change { AppUsageEvent.count }.by(1)
          event = AppUsageEvent.last
          expect(event).to match_app(app)
        end

        it 'does not create an AppUsageEvent when the app is STOPPED' do
          app = AppFactory.make(package_hash: 'abc', state: 'STOPPED')
          expect {
            app.update(memory: 2)
          }.not_to change { AppUsageEvent.count }
        end
      end

      context 'when a custom buildpack was used for staging' do
        it 'creates an AppUsageEvent that contains the custom buildpack url' do
          app = AppFactory.make(buildpack: 'https://example.com/repo.git', state: 'STOPPED')
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
          app = AppFactory.make(
            state: 'STOPPED',
            detected_buildpack: 'Admin buildpack detect string',
            detected_buildpack_guid: buildpack.guid
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
      let(:app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED', space: space) }

      it 'notifies the app observer', isolation: :truncation do
        expect(AppObserver).to receive(:deleted).with(app)
        app.destroy
      end

      it 'should nullify the routes' do
        app.add_route(route)
        expect {
          app.destroy
        }.to change { route.reload.apps.collect(&:guid) }.from([app.guid]).to([])
      end

      context 'when the service broker can successfully delete service bindings' do
        it 'should destroy all dependent service bindings' do
          service_binding = ServiceBinding.make(
            app: app,
            service_instance: ManagedServiceInstance.make(space: app.space)
          )
          stub_unbind(service_binding)

          expect {
            app.destroy
          }.to change { ServiceBinding.where(id: service_binding.id).count }.from(1).to(0)
        end
      end

      context 'when the service broker cannot successfully delete service bindings' do
        it 'should raise an exception when it fails to delete service bindings' do
          service_binding = ServiceBinding.make(
            app: app,
            service_instance: ManagedServiceInstance.make(:v2, space: app.space)
          )
          stub_unbind(service_binding, status: 500)

          expect {
            app.destroy
          }.to raise_error(VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse)
        end
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
        app = AppFactory.make(package_hash: 'abc', package_state: 'STAGED', space: space, state: 'STARTED')
        expect {
          app.destroy
        }.to change { AppUsageEvent.count }.by(1)
        expect(AppUsageEvent.last).to match_app(app)
      end

      it 'does not create an AppUsageEvent when the app state is STOPPED' do
        app = AppFactory.make(package_hash: 'abc', package_state: 'STAGED', space: space, state: 'STOPPED')
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
      subject(:app) do
        App.new
      end

      it 'sets the package hash to the image name any time the image is set' do
        expect {
          app.docker_image = 'foo/bar:latest'
        }.to change { app.package_hash }.to('foo/bar:latest')
      end

      it 'preserves its existing behavior as a setter' do
        expect {
          app.docker_image = 'foo/bar:latest'
        }.to change { app.docker_image }.to('foo/bar:latest')
      end

      user_docker_images = [
        'bar',
        'foo/bar',
        'foo/bar/baz',
        'fake.registry.com/bar',
        'fake.registry.com/foo/bar',
        'fake.registry.com/foo/bar/baz',
        'fake.registry.com:5000/bar',
        'fake.registry.com:5000/foo/bar',
        'fake.registry.com:5000/foo/bar/baz',
      ]

      user_docker_images.each do |partial_ref|
        complete_ref = partial_ref + ':0.1'
        it "keeps the user specified tag :0.1 on #{complete_ref}" do
          expect {
            app.docker_image = complete_ref
          }.to change { app.docker_image }.to end_with(':0.1')
        end
      end

      user_docker_images.each do |partial_ref|
        complete_ref = partial_ref + ':latest'
        it "keeps the user specified tag :latest on #{complete_ref}" do
          expect {
            app.docker_image = complete_ref
          }.to change { app.docker_image }.to end_with(':latest')
        end
      end

      user_docker_images.each do |partial_ref|
        it "inserts the tag :latest on #{partial_ref}" do
          expect {
            app.docker_image = partial_ref
          }.to change { app.docker_image }.to end_with(':latest')
        end
      end

      it 'does not allow a docker_image and an admin buildpack' do
        admin_buildpack = VCAP::CloudController::Buildpack.make
        app.buildpack = admin_buildpack.name
        expect {
          app.docker_image = 'foo/bar'
          app.save
        }.to raise_error(Sequel::ValidationFailed, /incompatible with buildpack/)
      end

      it 'does not allow a docker_image and a custom buildpack' do
        app.buildpack = 'git://user@github.com:repo'
        expect {
          app.docker_image = 'foo/bar'
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

      context 'when adding and removing routes', isolation: :truncation do
        let(:domain) do
          PrivateDomain.make owning_organization: subject.space.organization
        end

        let(:route) { Route.make domain: domain, space: subject.space }

        before do
          subject.diego = true
          allow(AppObserver).to receive(:routes_changed).with(subject)
          process_guid = Diego::ProcessGuid.from_app(subject)
          stub_request(:delete, "#{TestConfig.config[:diego_nsync_url]}/v1/apps/#{process_guid}").to_return(status: 202)
        end

        it 'does not update the app version' do
          expect { subject.add_route(route) }.to_not change(subject, :version)
          expect { subject.remove_route(route) }.to_not change(subject, :version)
        end

        it 'updates the app updated_at' do
          expect { subject.add_route(route) }.to change(subject, :updated_at)
          expect { subject.remove_route(route) }.to change(subject, :updated_at)
        end

        it 'calls the app observer with the app' do
          expect(AppObserver).to receive(:routes_changed).with(subject)
          subject.add_route(route)
        end

        it 'calls the app observer when route_guids are updated' do
          expect(AppObserver).to receive(:routes_changed).with(subject)

          subject.route_guids = [route.guid]
        end

        context 'when modifying multiple routes at one time' do
          let(:routes) { Array.new(3) { Route.make domain: domain, space: subject.space } }

          before do
            allow(AppObserver).to receive(:updated).with(subject)

            subject.add_route(route)
            subject.save
          end

          it 'calls the app observer once when multiple routes have changed' do
            expect(AppObserver).to receive(:routes_changed).with(subject).once

            App.db.transaction(savepoint: true) do
              subject.route_guids = routes.collect(&:guid)
              subject.remove_route(route)
              subject.save
            end
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
            app.ports = [1111, 2222]
            app.memory = 2048
            app.save
          }.to change(app, :version)
        end
      end
    end

    describe '#needs_package_in_current_state?' do
      it 'returns true if started' do
        app = App.new(state: 'STARTED', package_hash: nil)
        expect(app.needs_package_in_current_state?).to eq(true)
      end

      it 'returns false if not started' do
        expect(App.new(state: 'STOPPED', package_hash: nil).needs_package_in_current_state?).to eq(false)
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

      context 'when user does not provide ports' do
        let(:app) { App.make(diego: true) }

        it 'returns the default port' do
          expect(app.ports).to eq([8080])
        end

        it 'does not save the default ports to the DB' do
          expect(app.user_provided_ports).to be_nil
        end

        context 'when the app is a DEA app' do
          let(:app) { App.make }

          it 'returns nil' do
            app = App.make
            expect(app.ports).to be_nil
          end
        end
      end

      context 'docker app' do
        context 'when app is not staged' do
          let(:app) { App.make(diego: true, docker_image: 'some-docker-image', package_state: 'PENDING') }

          it 'returns the default ports' do
            expect(app.ports).to eq([8080])
          end

          it 'does not save the ports to the database' do
            expect(app.user_provided_ports).to be_nil
          end

          context 'when the app has a route' do
            let(:route) { Route.make(space: app.space) }
            before do
              app.add_route(route)
            end

            it 'should not save app_port to the route mappings' do
              route_mapping = RouteMapping.last
              expect(route_mapping.user_provided_app_port).to be_nil
            end

            it 'returns the default app_port for the route mapping' do
              route_mapping = RouteMapping.last
              expect(route_mapping.app_port).to eq(8080)
            end
          end
        end

        context 'when app is staged' do
          context 'when some tcp ports are exposed' do
            let(:app) {
              app = App.make(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
              app.add_droplet(Droplet.new(
                                app: app,
                                droplet_hash: 'the-droplet-hash',
                                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"tcp"}]}',
                              ))
              app.droplet_hash = 'the-droplet-hash'
              app
            }

            it 'returns the ports that were specified in the execution_metadata' do
              expect(app.ports).to eq([1024, 1025])
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
              app = App.make(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
              app.add_droplet(Droplet.new(
                                app: app,
                                droplet_hash: 'the-droplet-hash',
                                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"udp"}, {"Port":4444, "Protocol":"udp"},{"Port":1025, "Protocol":"udp"}]}',
                              ))
              app.droplet_hash = 'the-droplet-hash'
              expect(app.ports).to eq([8080])
              expect(app.user_provided_ports).to be_nil
            end
          end

          context 'when execution metadata is malformed' do
            it 'returns the ports that were specified during creation' do
              app = App.make(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1, ports: [1111])
              app.add_droplet(Droplet.new(
                                app: app,
                                droplet_hash: 'the-droplet-hash',
                                execution_metadata: 'some-invalid-json',
                              ))
              app.droplet_hash = 'the-droplet-hash'
              expect(app.user_provided_ports).to eq([1111])
              expect(app.ports).to eq([1111])
            end
          end

          context 'when no ports are specified in the execution metadata' do
            it 'returns the default port' do
              app = App.make(diego: true, docker_image: 'some-docker-image', package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
              app.add_droplet(Droplet.new(
                                app: app,
                                droplet_hash: 'the-droplet-hash',
                                execution_metadata: '{"cmd":"run.sh"}',
                              ))
              app.droplet_hash = 'the-droplet-hash'
              expect(app.ports).to eq([8080])
              expect(app.user_provided_ports).to be_nil
            end
          end
        end
      end

      context 'buildpack app' do
        context 'when app is not staged' do
          it 'returns the ports that were specified during creation' do
            app = App.make(diego: true, ports: [1025, 1026, 1027, 1028], package_state: 'PENDING')
            expect(app.ports).to eq([1025, 1026, 1027, 1028])
            expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
          end
        end

        context 'when app is staged' do
          context 'with no execution_metadata' do
            it 'returns the ports that were specified during creation' do
              app = App.make(diego: true, ports: [1025, 1026, 1027, 1028], package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
              expect(app.ports).to eq([1025, 1026, 1027, 1028])
              expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end

          context 'with execution_metadata' do
            it 'returns the ports that were specified during creation' do
              app = App.make(diego: true, ports: [1025, 1026, 1027, 1028], package_state: 'STAGED', package_hash: 'package-hash', instances: 1)
              app.add_droplet(Droplet.new(
                                app: app,
                                droplet_hash: 'the-droplet-hash',
                                execution_metadata: '{"ports":[{"Port":1024, "Protocol":"tcp"}, {"Port":4444, "Protocol":"udp"},{"Port":8080, "Protocol":"tcp"}]}',
                              ))
              app.droplet_hash = 'the-droplet-hash'
              expect(app.ports).to eq([1025, 1026, 1027, 1028])
              expect(app.user_provided_ports).to eq([1025, 1026, 1027, 1028])
            end
          end
        end
      end
    end
  end
end
