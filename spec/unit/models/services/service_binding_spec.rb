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

    describe '#required_parameters' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_binding) { ServiceBinding.make(service_instance: service_instance) }
      let(:app) { service_binding.app }

      it 'returns the required params' do
        expect(service_binding.required_parameters).to eq(
          app_guid: app.guid,
          space_guid: app.space.guid
        )
      end
    end
  end
end
