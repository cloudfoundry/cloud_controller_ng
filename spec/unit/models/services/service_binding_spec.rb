require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ServiceBinding, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :app, associated_instance: ->(binding) { AppModel.make(space: binding.space) } }
      it { is_expected.to have_associated :service_instance, associated_instance: ->(binding) { ServiceInstance.make(space: binding.space) } }

      it 'has a v2 app through the v3 app' do
        service_binding = ServiceBinding.make
        app = service_binding.app

        ProcessModel.make(app: app, type: 'non-web')
        expect(service_binding.reload.v2_app).to be_nil

        web_process = ProcessModel.make(app: app, type: 'web')
        expect(service_binding.reload.v2_app.guid).to eq(web_process.guid)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :app }
      it { is_expected.to validate_presence :service_instance }
      it { is_expected.to validate_db_presence :credentials }
      it { is_expected.to validate_uniqueness [:app_guid, :service_instance_guid], message: 'The app is already bound to the service.' }
      it { is_expected.to validate_presence [:type] }

      it 'validates max length of name' do
        too_long = 'a' * (255 + 1)

        binding = ServiceBinding.make
        binding.name = too_long

        expect { binding.save }.to raise_error(Sequel::ValidationFailed, /must be less than 256 characters/)
      end

      it 'validates max length of volume_mounts' do
        too_long = 'a' * (65_535 + 1)

        binding = ServiceBinding.make
        binding.volume_mounts = too_long

        expect { binding.save }.to raise_error(Sequel::ValidationFailed, /volume_mounts max_length/)
      end

      context 'validates name characters' do
        it 'does not allow non-word non-dash characters' do
          ['git://github.com', '$abc', 'foobar!'].each do |name|
            service_binding = ServiceBinding.new(name: name)
            expect(service_binding).not_to be_valid
            expect(service_binding.errors.on(:name)).to be_present
            expect(service_binding.errors.on(:name)).to include('The binding name is invalid. Valid characters are alphanumeric, underscore, and dash.')
          end
        end

        it 'allows word, underscore, and dash characters' do
          ['name', 'name-with-dash', '-name-', '_squ1d_'].each do |name|
            service_binding = ServiceBinding.new(name: name)
            service_binding.validate
            expect(service_binding.errors.on(:name)).not_to be_present
          end
        end
      end

      context 'when the syslog_drain_url is longer than 10,000 characters' do
        let(:overly_long_url) { "syslog://example.com/#{'s' * 10000}" }

        it 'refuses to save this service binding' do
          binding = ServiceBinding.make
          binding.syslog_drain_url = overly_long_url

          expect { binding.save }.to raise_error Sequel::ValidationFailed, /syslog_drain_url max_length/
        end
      end

      context 'when a binding already exists with the same app_guid and name' do
        let(:app) { AppModel.make }
        let(:service_instance) { ServiceInstance.make(space: app.space) }

        context 'and the name is not null' do
          let(:existing_binding) do
            ServiceBinding.make(app: app, name: 'some-name', service_instance: service_instance, type: 'app')
          end

          it 'adds a uniqueness error' do
            other_service_instance = ServiceInstance.make(space: existing_binding.space)
            conflict = ServiceBinding.new(app: existing_binding.app, name: existing_binding.name, service_instance: other_service_instance, type: 'app')
            expect(conflict.valid?).to be(false)
            expect(conflict.errors.full_messages).to eq(['The binding name is invalid. App binding names must be unique. The app already has a binding with name \'some-name\'.'])
          end
        end

        context 'and the name is null' do
          let(:existing_binding) do
            ServiceBinding.make(app: app, name: nil, service_instance: service_instance, type: 'app')
          end

          it 'does NOT add a uniqueness error' do
            other_service_instance = ServiceInstance.make(space: existing_binding.space)
            conflict = ServiceBinding.new(app: existing_binding.app, name: nil, service_instance: other_service_instance, type: 'app')
            expect(conflict.valid?).to be(true)
          end
        end
      end

      describe 'changing the binding after creation' do
        subject(:binding) { ServiceBinding.make }

        describe 'the associated app' do
          it 'allows changing to the same app' do
            binding.app = binding.app
            expect { binding.save }.not_to raise_error
          end

          it 'does not allow changing app after it has been set' do
            binding.app = AppModel.make
            expect { binding.save }.to raise_error Sequel::ValidationFailed, /app/
          end
        end

        describe 'the associated service instance' do
          it 'allows changing to the same service instance' do
            binding.service_instance = binding.service_instance
            expect { binding.save }.not_to raise_error
          end

          it 'does not allow changing service_instance after it has been set' do
            binding.service_instance = ServiceInstance.make(space: binding.app.space)
            expect { binding.save }.to raise_error Sequel::ValidationFailed, /service_instance/
          end
        end
      end

      describe 'service instance and app space matching' do
        let(:app) { AppModel.make }

        context 'when the service instance and the app are in different spaces' do
          let(:service_instance) { ManagedServiceInstance.make }
          context 'when the service instance has not been shared into the app space' do
            it 'is not valid' do
              expect { ServiceBinding.make(service_instance: service_instance, app: app)
              }.to raise_error(Sequel::ValidationFailed, /service_instance space_mismatch/)
            end
          end

          context 'when the service instance has been shared into the app space' do
            before do
              service_instance.add_shared_space(app.space)
            end

            it 'is valid' do
              expect(ServiceBinding.make(service_instance: service_instance, app: app)).to be_valid
            end
          end
        end

        context 'when the service instance and the app are in the same space' do
          let(:service_instance) { ManagedServiceInstance.make(space: app.space) }

          it 'is valid' do
            expect(ServiceBinding.make(service_instance: service_instance, app: app)).to be_valid
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to import_attributes :app_guid, :service_instance_guid, :credentials, :syslog_drain_url, :name }
    end

    describe '#new' do
      it 'has a guid when constructed' do
        binding = VCAP::CloudController::ServiceBinding.new
        expect(binding.guid).to be
      end
    end

    describe 'encrypted columns' do
      describe 'credentials' do
        it_behaves_like 'a model with an encrypted attribute' do
          let(:service_instance) { ManagedServiceInstance.make }

          def new_model
            ServiceBinding.make(
              service_instance: service_instance,
              credentials: value_to_encrypt
            )
          end

          let(:encrypted_attr) { :credentials }
          let(:attr_salt) { :salt }
        end
      end

      describe 'volume_mounts' do
        it_behaves_like 'a model with an encrypted attribute' do
          let(:service_instance) { ManagedServiceInstance.make }

          def new_model
            ServiceBinding.make(
              service_instance: service_instance,
              volume_mounts: value_to_encrypt
            )
          end

          let(:encrypted_attr) { :volume_mounts }
        end
      end
    end

    describe '#in_suspended_org?' do
      let(:app_model) { VCAP::CloudController::AppModel.make }
      subject(:service_binding) { VCAP::CloudController::ServiceBinding.new(app: app_model) }

      context 'when in a suspended organization' do
        before { allow(app_model.space).to receive(:in_suspended_org?).and_return(true) }
        it 'is true' do
          expect(service_binding).to be_in_suspended_org
        end
      end

      context 'when in an unsuspended organization' do
        before { allow(app_model.space).to receive(:in_suspended_org?).and_return(false) }
        it 'is false' do
          expect(service_binding).not_to be_in_suspended_org
        end
      end
    end

    describe 'logging service bindings' do
      let(:service) { Service.make }
      let(:service_plan) { ServicePlan.make(service: service) }
      let(:service_instance) do
        ManagedServiceInstance.make(
          service_plan: service_plan,
          name: 'not a syslog drain instance'
        )
      end

      context 'service that does not require syslog_drain' do
        let(:service) { Service.make(requires: []) }

        it 'should allow a non syslog_drain with a nil syslog drain url' do
          expect {
            service_binding = ServiceBinding.make(service_instance: service_instance)
            service_binding.syslog_drain_url = nil
            service_binding.save
          }.not_to raise_error
        end

        it 'should allow a non syslog_drain with an empty syslog drain url' do
          expect {
            service_binding = ServiceBinding.make(service_instance: service_instance)
            service_binding.syslog_drain_url = ''
            service_binding.save
          }.not_to raise_error
        end
      end

      context 'service that does require a syslog_drain' do
        let(:service) { Service.make(requires: ['syslog_drain']) }

        it 'should allow a syslog_drain with a syslog drain url' do
          expect {
            service_binding = ServiceBinding.make(service_instance: service_instance)
            service_binding.syslog_drain_url = 'http://syslogurl.com'
            service_binding.save
          }.not_to raise_error
        end
      end
    end

    describe 'restaging' do
      let(:v2_app) { ProcessModelFactory.make(state: 'STARTED', instances: 1, type: 'web') }
      let(:service_instance) { ManagedServiceInstance.make(space: v2_app.space) }

      it 'should not trigger restaging when creating a binding' do
        ServiceBinding.make(app: v2_app.app, service_instance: service_instance)
        v2_app.refresh
        expect(v2_app.needs_staging?).to be false
      end

      it 'should not trigger restaging when directly destroying a binding' do
        binding = ServiceBinding.make(app: v2_app.app, service_instance: service_instance)
        expect { binding.destroy }.not_to change { v2_app.refresh.needs_staging? }.from(false)
      end
    end

    describe '#service_instance_name' do
      let(:v2_app) { ProcessModelFactory.make(state: 'STARTED', instances: 1, type: 'web') }
      let(:service_instance) { ManagedServiceInstance.make(space: v2_app.space) }

      it 'returns the name of the associated service instance' do
        binding = ServiceBinding.make(app: v2_app.app, service_instance: service_instance)
        expect(binding.service_instance_name).to eq(service_instance.name)
      end
    end

    describe '#user_visibility_filter' do
      let(:app_model) { AppModel.make }
      let!(:service_instance) { ManagedServiceInstance.make }
      let!(:other_binding) { ServiceBinding.make }
      let!(:service_binding) do
        service_instance.add_shared_space(app_model.space)
        ServiceBinding.make(service_instance: service_instance, app: app_model)
      end

      context "when a user is a developer in the app's space" do
        let(:user) { make_developer_for_space(app_model.space) }

        it 'the service binding is visible' do
          expect(ServiceBinding.user_visible(user).all).to eq [service_binding]
        end
      end

      context "when a user is an auditor in the app's space" do
        let(:user) { make_auditor_for_space(app_model.space) }

        it 'the service binding is visible' do
          expect(ServiceBinding.user_visible(user).all).to eq [service_binding]
        end
      end

      context "when a user is an org manager in the app's space" do
        let(:user) { make_manager_for_org(app_model.space.organization) }

        it 'the service binding is visible' do
          expect(ServiceBinding.user_visible(user).all).to eq [service_binding]
        end
      end

      context "when a user is a space manager in the app's space" do
        let(:user) { make_manager_for_space(app_model.space) }

        it 'the service binding is visible' do
          expect(ServiceBinding.user_visible(user).all).to eq [service_binding]
        end
      end

      context "when a user has no access to the app's space or the service instance's space" do
        let(:user) { User.make }

        it 'the service binding is not visible' do
          expect(ServiceBinding.user_visible(user).all).to be_empty
        end
      end

      context "when a user has read access to the service instance's space, but not the app's" do
        let(:user) { make_developer_for_space(service_instance.space) }

        it 'the service binding is not visible' do
          expect(ServiceBinding.user_visible(user).all).to be_empty
        end
      end
    end

    describe 'is_created?' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

      context 'when the service binding has been created synchronously' do
        it 'returns true' do
          expect(service_binding.is_created?).to be true
        end
      end

      context 'when the service binding is being created asynchronously' do
        let(:state) {}
        let(:operation) { ServiceBindingOperation.make(type: 'create', state: state) }

        before do
          service_binding.service_binding_operation = operation
        end

        context 'and the operation is in progress' do
          let(:state) { 'in progress' }

          it 'returns false' do
            expect(service_binding.is_created?).to be false
          end
        end

        context 'and the operation has failed' do
          let(:state) { 'failed' }

          it 'returns false' do
            expect(service_binding.is_created?).to be false
          end
        end

        context 'and the operation has succeeded' do
          let(:state) { 'succeeded' }

          it 'returns true' do
            expect(service_binding.is_created?).to be true
          end
        end
      end

      context 'when the service binding is being deleted asynchronously' do
        let(:state) {}
        let(:operation) { ServiceBindingOperation.make(type: 'delete', state: state) }

        before do
          service_binding.service_binding_operation = operation
        end

        context 'and the operation is in progress' do
          let(:state) { 'in progress' }

          it 'returns true' do
            expect(service_binding.is_created?).to be true
          end
        end

        context 'and the operation has failed' do
          let(:state) { 'failed' }

          it 'returns true' do
            expect(service_binding.is_created?).to be true
          end
        end

        context 'and the operation has succeeded' do
          let(:state) { 'succeeded' }

          it 'returns false' do
            expect(service_binding.is_created?).to be false
          end
        end
      end
    end

    describe '#save_with_new_operation' do
      let(:service_instance) { ServiceInstance.make }
      let(:app) { AppModel.make(space: service_instance.space) }
      let(:binding) {
        ServiceBinding.new(
          service_instance: service_instance,
          app: app,
          credentials: {},
          type: 'app',
          name: 'foo',
        )
      }

      it 'creates a new last_operation object and associates it with the binding' do
        last_operation = {
          state: 'in progress',
          type: 'create',
          description: '10%'
        }
        binding.save_with_new_operation(last_operation)

        expect(binding.last_operation.state).to eq 'in progress'
        expect(binding.last_operation.description).to eq '10%'
        expect(binding.last_operation.type).to eq 'create'
        expect(ServiceBinding.where(guid: binding.guid).count).to eq(1)
      end

      context 'when saving the binding operation fails' do
        before do
          allow(ServiceBindingOperation).to receive(:create).and_raise(Sequel::DatabaseError, 'failed to create new-binding operation')
        end

        it 'should rollback the binding' do
          expect { binding.save_with_new_operation({ state: 'will fail' }) }.to raise_error(Sequel::DatabaseError)
          expect(ServiceBinding.where(guid: binding.guid).count).to eq(0)
        end
      end

      context 'when called twice' do
        it 'does saves the second operation' do
          binding.save_with_new_operation({ state: 'in progress', type: 'create', description: 'description' })
          binding.save_with_new_operation({ state: 'in progress', type: 'delete' })

          expect(binding.last_operation.state).to eq 'in progress'
          expect(binding.last_operation.type).to eq 'delete'
          expect(binding.last_operation.description).to eq nil
          expect(ServiceBinding.where(guid: binding.guid).count).to eq(1)
          expect(ServiceBindingOperation.where(service_binding_id: binding.id).count).to eq(1)
        end
      end

      context 'when attributes are passed in' do
        let(:credentials) { { password: 'rice' } }
        let(:syslog_drain_url) { 'http://foo.example.com/bar' }
        let(:volume_mounts) { [{
          container_dir: '/var/vcap/data/153e3c4b-1151-4cf7-b311-948dd77fce64',
          device_type: 'shared',
          mode: 'rw'
        }.with_indifferent_access]
        }
        let(:attributes) {
          {
            name: 'gohan',
            credentials: credentials,
            syslog_drain_url: syslog_drain_url,
            volume_mounts: volume_mounts
          }
        }
        let(:last_operation) { {
          state: 'in progress',
          type: 'create',
          description: '10%'
        }
        }

        it 'updates the attributes' do
          binding.save_with_new_operation(last_operation, attributes: attributes)
          binding.reload
          expect(binding.last_operation.state).to eq 'in progress'
          expect(binding.last_operation.description).to eq '10%'
          expect(binding.last_operation.type).to eq 'create'
          expect(binding.name).to eq 'gohan'
          expect(binding.credentials).to eq(credentials.with_indifferent_access)
          expect(binding.syslog_drain_url).to eq('http://foo.example.com/bar')
          expect(binding.volume_mounts).to eq(volume_mounts)
          expect(ServiceBinding.where(guid: binding.guid).count).to eq(1)
        end

        it 'only saves permitted attributes' do
          expect {
            binding.save_with_new_operation(last_operation, attributes: attributes.merge(
              parameters: {
                foo: 'bar',
                ding: 'dong'
              },
              endpoints: [{ host: 'mysqlhost', ports: ['3306'] }],
              route_services_url: 'http://route.example.com'
            ))
          }.not_to raise_error
        end
      end
    end

    describe '#terminal_state?' do
      let(:service_binding) { ServiceBinding.make }
      let(:operation) { ServiceBindingOperation.make(state: state) }

      before do
        service_binding.service_binding_operation = operation
      end

      context 'when state is succeeded' do
        let(:state) { 'succeeded' }

        it 'returns true' do
          expect(service_binding.terminal_state?).to be true
        end
      end

      context 'when state is failed' do
        let(:state) { 'failed' }

        it 'returns true when state is `failed`' do
          expect(service_binding.terminal_state?).to be true
        end
      end

      context 'when state is something else' do
        let(:state) { 'in progress' }

        it 'returns false' do
          expect(service_binding.terminal_state?).to be false
        end
      end

      context 'when binding operation is missing' do
        let(:operation) { nil }

        it 'returns true' do
          expect(service_binding.terminal_state?).to be true
        end
      end
    end

    describe 'operation_in_progress?' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }

      context 'when the service binding has been created synchronously' do
        it 'returns false' do
          expect(service_binding.operation_in_progress?).to be false
        end
      end

      context 'when the service binding is being created asynchronously' do
        let(:state) {}
        let(:operation) { ServiceBindingOperation.make(state: state) }

        before do
          service_binding.service_binding_operation = operation
        end

        context 'and the operation is in progress' do
          let(:state) { 'in progress' }

          it 'returns true' do
            expect(service_binding.operation_in_progress?).to be true
          end
        end

        context 'and the operation has failed' do
          let(:state) { 'failed' }

          it 'returns false' do
            expect(service_binding.operation_in_progress?).to be false
          end
        end

        context 'and the operation has succeeded' do
          let(:state) { 'succeeded' }

          it 'returns false' do
            expect(service_binding.operation_in_progress?).to be false
          end
        end
      end
    end

    describe '#destroy' do
      it 'cascades deletion of related dependencies' do
        binding = ServiceBinding.make
        ServiceBindingLabelModel.make(key_name: 'foo', value: 'bar', service_binding: binding)
        ServiceBindingAnnotationModel.make(key_name: 'baz', value: 'wow', service_binding: binding)
        last_operation = ServiceBindingOperation.make
        binding.service_binding_operation = last_operation

        binding.destroy

        expect(ServiceBinding.find(guid: binding.guid)).to be_nil
        expect(ServiceBindingOperation.find(id: last_operation.id)).to be_nil
        expect(ServiceBindingLabelModel.find(resource_guid: binding.guid)).to be_nil
        expect(ServiceBindingAnnotationModel.find(resource_guid: binding.guid)).to be_nil
      end
    end
  end
end
