require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ServiceInstance, type: :model do
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
        it 'eager loads successfully' do
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

    describe 'validations' do
      context 'when the name is longer than 255 characters' do
        let(:very_long_name) { 's' * 256 }
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

      context 'when the syslog_drain_url is longer than 10,000 characters' do
        let(:overly_long_url) { "syslog://example.com/#{'s' * 10000}" }

        it 'refuses to create this service instance' do
          service_instance_attrs[:syslog_drain_url] = overly_long_url
          expect { service_instance }.to raise_error Sequel::ValidationFailed, /syslog_drain_url max_length/
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
              service_instance_foo.set(name: 'bar')
              service_instance_foo.save_changes
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end
        end
      end

      describe 'when two are created with the same name' do
        describe 'when a UserProvidedServiceInstance exists' do
          before { UserProvidedServiceInstance.create(service_instance_attrs) }

          it 'raises an exception when creating another UserProvidedServiceInstance' do
            expect {
              UserProvidedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end

          it 'raises an exception when creating a ManagedServiceInstance' do
            expect {
              ManagedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
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
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end

          it 'raises an exception when creating a UserProvidedServiceInstance' do
            expect {
              UserProvidedServiceInstance.create(service_instance_attrs)
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end
        end

        describe 'when a ManagedServiceInstance has been shared' do
          let(:space) { Space.make }
          let(:originating_space) { Space.make }
          let(:service_instance) {
            ManagedServiceInstance.make(name: 'shared-service', space: originating_space)
          }

          before do
            service_instance.add_shared_space(space)
          end

          it 'raises an exception when creating another ManagedServiceInstance' do
            expect {
              ManagedServiceInstance.make(name: 'shared-service', space: space)
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end

          it 'raises an exception when creating another UserProvidedServiceInstance' do
            expect {
              UserProvidedServiceInstance.make(name: 'shared-service', space: space)
            }.to raise_error(Sequel::ValidationFailed, /name unique/)
          end
        end
      end
    end

    describe '#create' do
      describe 'when is_gateway_service is false' do
        it 'returns a UserProvidedServiceInstance' do
          service_instance_attrs[:is_gateway_service] = false
          service_instance = ServiceInstance.create(service_instance_attrs)
          expect(ServiceInstance.find(guid: service_instance.guid).class).to eq(VCAP::CloudController::UserProvidedServiceInstance)
        end
      end

      describe 'when is_gateway_service is true' do
        it 'returns a ManagedServiceInstance' do
          service_instance_attrs[:is_gateway_service] = true
          service_instance = ServiceInstance.create(service_instance_attrs)
          expect(ServiceInstance.find(guid: service_instance.guid).class).to eq(VCAP::CloudController::ManagedServiceInstance)
        end
      end
    end

    describe '#destroy' do
      let!(:service_instance) { ServiceInstance.create(service_instance_attrs) }

      it 'deletes associated resources' do
        label = ServiceInstanceLabelModel.make(resource_guid: service_instance.guid, key_name: 'foo', value: 'bar')
        annotation = ServiceInstanceAnnotationModel.make(resource_guid: service_instance.guid, key: 'alpha', value: 'beta')

        service_instance.destroy

        expect(ServiceInstanceLabelModel.where(id: label.id)).to be_empty
        expect(ServiceInstanceAnnotationModel.where(id: annotation.id)).to be_empty
      end

      it 'creates a DELETED service usage event' do
        expect {
          service_instance.destroy
        }.to change { ServiceUsageEvent.count }.by(1)
        event = ServiceUsageEvent.last
        expect(event.state).to eq(Repositories::ServiceUsageEventRepository::DELETED_EVENT_STATE)
        expect(event).to match_service_instance(service_instance)
      end
    end

    describe '#update' do
      let!(:service_instance) { ManagedServiceInstance.make }

      context 'updating service_plan' do
        let!(:service_plan) { ServicePlan.make }

        it 'creates an UPDATE service usage event' do
          expect {
            service_instance.set(service_plan: service_plan)
            service_instance.save_changes
          }.to change { ServiceUsageEvent.count }.by 1

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end
      end

      context 'updating the service instance name' do
        let(:new_name) { 'some-new-name' }
        it 'creates an UPDATE service usage event' do
          expect {
            service_instance.set(name: new_name)
            service_instance.save_changes
          }.to change { ServiceUsageEvent.count }.by 1

          event = ServiceUsageEvent.last
          expect(event.state).to eq(Repositories::ServiceUsageEventRepository::UPDATED_EVENT_STATE)
          expect(event).to match_service_instance(service_instance)
        end
      end

      context 'when a service binding exists' do
        let(:process) { ProcessModelFactory.make(space: service_instance.space) }
        let(:process2) { ProcessModelFactory.make(space: service_instance.space) }
        let!(:service_binding) {
          ServiceBinding.make(app_guid: process.app.guid, service_instance_guid: service_instance.guid)
        }
        let!(:service_binding2) {
          ServiceBinding.make(app_guid: process2.app.guid, service_instance_guid: service_instance.guid)
        }

        context 'and syslog_drain_url changes' do
          it 'updates the service binding' do
            expect {
              service_instance.update(syslog_drain_url: 'syslog-tls://logs.example.com')
            }.to change {
              service_binding.reload.syslog_drain_url
            }.to('syslog-tls://logs.example.com')
            expect(service_binding2.reload.syslog_drain_url).to eq('syslog-tls://logs.example.com')
          end
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

    describe '#shareable?' do
      it 'returns false' do
        expect(service_instance.shareable?).to be_falsey
      end
    end

    describe '#as_summary_json' do
      it 'contains name, guid, binding count and type' do
        instance = VCAP::CloudController::ServiceInstance.make(
          guid: 'ABCDEFG12',
          name: 'Random-Number-Service',
        )
        VCAP::CloudController::ServiceBinding.make(service_instance: instance)

        expect(instance.as_summary_json).to eq({
          'guid' => 'ABCDEFG12',
          'name' => 'Random-Number-Service',
          'bound_app_count' => 1,
          'type' => 'service_instance',
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

      context 'when the service instance space is not visible' do
        let(:space) { nil }

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

    describe '#user_visibility_filter' do
      let(:developer)     { make_developer_for_space(service_instance.space) }
      let(:auditor)       { make_auditor_for_space(service_instance.space) }
      let(:user)          { make_user_for_space(service_instance.space) }
      let(:org_manager)   { make_manager_for_org(service_instance.space.organization) }
      let(:space_manager) { make_manager_for_space(service_instance.space) }

      context 'when a user is an org manager where the instance was created' do
        it 'the service instance is visible' do
          filter = ServiceInstance.user_visibility_filter(org_manager)
          expect(ServiceInstance.filter(filter).all.length).to eq(1)
        end
      end

      context 'when a user is a space developer in the space the instance was created' do
        it 'the service instance is visible' do
          filter = ServiceInstance.user_visibility_filter(developer)
          expect(ServiceInstance.filter(filter).all.length).to eq(1)
        end
      end

      context 'when a user is a space auditor in the space the instance was created' do
        it 'the service instance is visible' do
          filter = ServiceInstance.user_visibility_filter(auditor)
          expect(ServiceInstance.filter(filter).all.length).to eq(1)
        end
      end

      context 'when a user is a space manager in the space the instance was created' do
        it 'the service instance is visible' do
          filter = ServiceInstance.user_visibility_filter(space_manager)
          expect(ServiceInstance.filter(filter).all.length).to eq(1)
        end
      end

      context 'when a user does not have access to the originating space' do
        it 'the service instance is not visible' do
          filter = ServiceInstance.user_visibility_filter(user)
          expect(ServiceInstance.filter(filter).all.length).to eq(0)
        end
      end

      context 'when the service instance is shared' do
        let(:target_space)     { VCAP::CloudController::Space.make }
        let(:target_space_dev) { make_developer_for_space(target_space) }
        let(:target_org_user) { make_user_for_org(target_space.organization) }
        let(:target_space_auditor) { make_auditor_for_space(target_space) }
        let(:target_space_manager) { make_manager_for_space(target_space) }
        let(:target_space_org_manager) { make_manager_for_org(target_space.organization) }

        before do
          service_instance.add_shared_space(target_space)
        end

        context 'when a user is a space developer in the target space' do
          it 'the service instance is visible' do
            filter = ServiceInstance.user_visibility_filter(target_space_dev)
            expect(ServiceInstance.filter(filter).all.length).to eq(1)
          end
        end

        context 'when a user is a space developer in the source space' do
          it 'the service instance is visible' do
            filter = ServiceInstance.user_visibility_filter(developer)
            expect(ServiceInstance.filter(filter).all.length).to eq(1)
          end
        end

        context 'when a user is a space auditor in the target space' do
          it 'the service instance is visible' do
            filter = ServiceInstance.user_visibility_filter(target_space_auditor)
            expect(ServiceInstance.filter(filter).all.length).to eq(1)
          end
        end

        context 'when a user is a space manager in the target space' do
          it 'the service instance is visible' do
            filter = ServiceInstance.user_visibility_filter(target_space_manager)
            expect(ServiceInstance.filter(filter).all.length).to eq(1)
          end
        end

        context 'when a user is a org manager in the target space' do
          it 'the service instance is visible' do
            filter = ServiceInstance.user_visibility_filter(target_space_org_manager)
            expect(ServiceInstance.filter(filter).all.length).to eq(1)
          end
        end

        context 'when a user does not have access to the target space' do
          it 'the service instance is not visible' do
            filter = ServiceInstance.user_visibility_filter(target_org_user)
            expect(ServiceInstance.filter(filter).all.length).to eq(0)
          end
        end
      end
    end

    describe '#shared?' do
      context 'when the service instance has shared spaces' do
        before do
          service_instance.add_shared_space(Space.make)
        end

        it 'returns true' do
          expect(service_instance.shared?).to be true
        end
      end

      context 'when the service instance does not have shared spaces' do
        it 'returns false' do
          expect(service_instance.shared?).to be false
        end
      end
    end

    describe '#has_bindings?' do
      it 'returns true when there are bindings' do
        ServiceBinding.make(service_instance: service_instance)
        expect(service_instance).to have_bindings
      end

      it 'returns false when there are no bindings' do
        expect(service_instance).not_to have_bindings
      end
    end

    describe '#has_keys?' do
      it 'returns true when there are keys' do
        ServiceKey.make(service_instance: service_instance)
        expect(service_instance).to have_keys
      end

      it 'returns false when there are no keys' do
        expect(service_instance).not_to have_keys
      end
    end

    describe '#has_routes?' do
      it 'returns true when there are routes' do
        allow(service_instance).to receive(:route_service?).and_return(true)
        RouteBinding.make(service_instance: service_instance, route: Route.make(space: service_instance.space))
        expect(service_instance).to have_routes
      end

      it 'returns false when there are no routes' do
        expect(service_instance).not_to have_routes
      end
    end

    describe 'metadata' do
      let(:service_instance) { ServiceInstance.make }
      let(:annotation) { ServiceInstanceAnnotationModel.make(service_instance: service_instance) }
      let(:label) { ServiceInstanceLabelModel.make(service_instance: service_instance) }

      it 'can access a service_instance from its metadata' do
        expect(annotation.resource_guid).to eq(service_instance.guid)
        expect(label.resource_guid).to eq(service_instance.guid)
        expect(service_instance.labels).to match_array([label])
        expect(service_instance.annotations).to match_array([annotation])
      end
    end
  end
end
