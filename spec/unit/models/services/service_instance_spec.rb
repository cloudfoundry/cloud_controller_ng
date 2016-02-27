require 'spec_helper'

module VCAP::CloudController
  describe ServiceInstance, type: :model do
    let(:service_instance_attrs)  do
      {
        name: 'my favorite service',
        space: VCAP::CloudController::Space.make
      }
    end

    let(:service_instance) { ServiceInstance.create(service_instance_attrs) }

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      describe 'service_plan_sti_eager_load' do
        it 'eager loads successfuly' do
          service_plan = ServicePlan.make.reload
          instance1 = ManagedServiceInstance.make(service_plan: service_plan)
          instance2 = ManagedServiceInstance.make
          eager_loaded_instances = nil
          expect {
            eager_loaded_instances = ServiceInstance.eager(:service_plan_sti_eager_load).all.to_a
          }.to have_queried_db_times(/service_plans/i, 1)

          expect {
            eager_loaded_instances.each(&:service_plan)
          }.to have_queried_db_times(//i, 0)

          found_instance1 = eager_loaded_instances.detect { |instance| instance.id == instance1.id }
          found_instance2 = eager_loaded_instances.detect { |instance| instance.id == instance2.id }
          expect(found_instance1.service_plan).to eq(service_plan)
          expect(found_instance2.service_plan).to_not eq(service_plan)
        end
      end

      describe 'changing space' do
        it 'fails when existing service bindings are in a different space' do
          service_instance.add_service_binding(ServiceBinding.make(service_instance: service_instance))
          expect { service_instance.space = Space.make }.to raise_error ServiceInstance::InvalidServiceBinding
        end
      end
    end

    describe '#create' do
      context 'when the name is longer than 50 characters' do
        let(:very_long_name) { 's' * 51 }
        it 'refuses to create this service instance' do
          service_instance_attrs[:name] = very_long_name
          expect { service_instance }.to raise_error Sequel::ValidationFailed
        end
      end

      context 'when the name is blank' do
        let(:blank_name) { '' }
        let(:service_instance) { ServiceInstance.new(service_instance_attrs) }

        it 'returns a ServiceInstanceNameEmpty error' do
          service_instance_attrs[:name] = blank_name
          service_instance.validate
          expect(service_instance.errors.on(:name)).to eq([:presence])
        end
      end

      describe 'when is_gateway_service is false' do
        it 'returns a UserProvidedServiceInstance' do
          service_instance_attrs[:is_gateway_service] = false
          service_instance = described_class.create(service_instance_attrs)
          expect(described_class.find(guid: service_instance.guid).class).to eq(VCAP::CloudController::UserProvidedServiceInstance)
        end
      end

      describe 'when is_gateway_service is true' do
        it 'returns a ManagedServiceInstance' do
          service_instance_attrs[:is_gateway_service] = true
          service_instance = described_class.create(service_instance_attrs)
          expect(described_class.find(guid: service_instance.guid).class).to eq(VCAP::CloudController::ManagedServiceInstance)
        end
      end

      describe 'when one service instance is renamed to an existing service instance name' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:service_instance_attrs_foo) { { name: 'foo', space: space } }
        let(:service_instance_attrs_bar) { { name: 'bar', space: space } }

        describe 'when both service instances are user provided service instances' do
          let!(:service_instance_foo) { UserProvidedServiceInstance.create(service_instance_attrs_foo) }
          let!(:service_instance_bar) { UserProvidedServiceInstance.create(service_instance_attrs_bar) }

          it 'raises an exception when renaming the service' do
            expect {
              service_instance_foo.set_all(name: 'bar')
              service_instance_foo.save_changes
            }.to raise_error(Sequel::ValidationFailed, /space_id and name unique/)
          end
        end
      end

      describe 'when two are created with the same name' do
        describe 'when a UserProvidedServiceInstance exists' do
          before { UserProvidedServiceInstance.create(service_instance_attrs) }

          it 'raises an exception when creating another UserProvidedServiceInstance' do
            expect {
              UserProvidedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /space_id and name unique/)
          end

          it 'raises an exception when creating a ManagedServiceInstance' do
            expect {
              ManagedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /space_id and name unique/)
          end
        end

        describe 'when a ManagedServiceInstance exists' do
          before do
            service_plan = ServicePlan.make.reload
            ManagedServiceInstance.create(service_instance_attrs.merge(service_plan: service_plan))
          end

          it 'raises an exception when creating another ManagedServiceInstance' do
            expect {
              ManagedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /space_id and name unique/)
          end

          it 'raises an exception when creating a UserProvidedServiceInstance' do
            expect {
              UserProvidedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /space_id and name unique/)
          end
        end
      end
    end

    describe '#destroy' do
      let!(:service_instance) { ServiceInstance.create(service_instance_attrs) }

      it 'creates a DELETED service usage event' do
        expect {
          service_instance.destroy
        }.to change { ServiceUsageEvent.count }.by(1)
        event = ServiceUsageEvent.last
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::DELETED_EVENT_STATE)
        expect(event).to match_service_instance(service_instance)
      end
    end

    describe '#update' do
      let!(:service_instance) { ManagedServiceInstance.make }

      context 'updating service_plan' do
        let!(:service_plan) { ServicePlan.make }

        it 'creates an UPDATE service usage event' do
          expect {
            service_instance.set_all(service_plan: service_plan)
            service_instance.save_changes
          }.to change { ServiceUsageEvent.count }.by 1

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end
      end

      context 'updating the service instance name' do
        let(:new_name) { 'some-new-name' }
        it 'creates an UPDATE service usage event' do
          expect {
            service_instance.set_all(name: new_name)
            service_instance.save_changes
          }.to change { ServiceUsageEvent.count }.by 1

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end
      end
    end

    describe '#credentials' do
      let(:content) { { 'foo' => 'bar' } }

      it 'stores and returns a hash' do
        service_instance.credentials = content
        expect(service_instance.credentials).to eq(content)
      end

      it 'stores and returns a nil value' do
        service_instance.credentials = nil
        expect(service_instance.credentials).to eq(nil)
      end
    end

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :credentials }
      let(:attr_salt) { :salt }
    end

    describe '#type' do
      it 'returns the model name for API consumption' do
        managed_instance = VCAP::CloudController::ManagedServiceInstance.new
        expect(managed_instance.type).to eq 'managed_service_instance'

        user_provided_instance = VCAP::CloudController::UserProvidedServiceInstance.new
        expect(user_provided_instance.type).to eq 'user_provided_service_instance'
      end
    end

    describe '#user_provided_instance?' do
      it 'returns true for ManagedServiceInstance instances' do
        managed_instance = VCAP::CloudController::ManagedServiceInstance.new
        expect(managed_instance.user_provided_instance?).to eq(false)
      end

      it 'returns false for ManagedServiceInstance instances' do
        user_provided_instance = VCAP::CloudController::UserProvidedServiceInstance.new
        expect(user_provided_instance.user_provided_instance?).to eq(true)
      end
    end

    describe '#route_service?' do
      it 'returns false' do
        expect(service_instance.route_service?).to be_falsey
      end
    end

    describe '#bindable?' do
      it { is_expected.to be_bindable }
    end

    describe '#as_summary_json' do
      it 'contains name, guid, and binding count' do
        instance = VCAP::CloudController::ServiceInstance.make(
          guid: 'ABCDEFG12',
          name: 'Random-Number-Service',
        )
        VCAP::CloudController::ServiceBinding.make(service_instance: instance)

        expect(instance.as_summary_json).to eq({
          'guid' => 'ABCDEFG12',
          'name' => 'Random-Number-Service',
          'bound_app_count' => 1,
        })
      end
    end

    describe '#in_suspended_org?' do
      let(:space) { VCAP::CloudController::Space.make }
      subject(:service_instance) { VCAP::CloudController::ServiceInstance.new(space: space) }

      context 'when in a suspended organization' do
        before { allow(space).to receive(:in_suspended_org?).and_return(true) }
        it 'is true' do
          expect(service_instance).to be_in_suspended_org
        end
      end

      context 'when in an unsuspended organization' do
        before { allow(space).to receive(:in_suspended_org?).and_return(false) }
        it 'is false' do
          expect(service_instance).not_to be_in_suspended_org
        end
      end
    end

    describe '#to_hash' do
      let(:opts)      { { attrs: [:credentials] } }
      let(:developer) { make_developer_for_space(service_instance.space) }
      let(:auditor)   { make_auditor_for_space(service_instance.space) }
      let(:user)      { make_user_for_space(service_instance.space) }

      it 'does not redact creds for an admin' do
        allow(VCAP::CloudController::SecurityContext).to receive(:admin?).and_return(true)
        expect(service_instance.to_hash['credentials']).not_to eq({ redacted_message: '[PRIVATE DATA HIDDEN]' })
      end

      it 'does not redact creds for a space developer' do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(developer)
        expect(service_instance.to_hash['credentials']).not_to eq({ redacted_message: '[PRIVATE DATA HIDDEN]' })
      end

      it 'redacts creds for a space auditor' do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(auditor)
        expect(service_instance.to_hash(opts)['credentials']).to eq({ redacted_message: '[PRIVATE DATA HIDDEN]' })
      end

      it 'redacts creds for a space user' do
        allow(VCAP::CloudController::SecurityContext).to receive(:current_user).and_return(user)
        expect(service_instance.to_hash(opts)['credentials']).to eq({ redacted_message: '[PRIVATE DATA HIDDEN]' })
      end
    end
  end
end
