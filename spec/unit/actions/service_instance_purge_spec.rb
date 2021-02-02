require 'spec_helper'
require 'actions/service_instance_purge'

module VCAP::CloudController
  RSpec.describe ServiceInstancePurge do
    let(:user_audit_info) { UserAuditInfo.new(user_guid: User.make.guid, user_email: 'email') }
    let(:event_repository) { Repositories::ServiceEventRepository.new(user_audit_info) }
    subject { described_class.new(event_repository) }

    RSpec.shared_examples 'delete service instance' do
      it 'deletes the service instance' do
        subject.purge(service_instance)
        expect(service_instance).not_to exist
      end

      it 'records a service instance purge event' do
        subject.purge(service_instance)
        event = Event.last
        expect(event.type).to eq('audit.service_instance.purge')
        expect(event.actee).to eq(service_instance.guid)
      end

      it 'records a service usage event for DELETED' do
        subject.purge(service_instance)
        event = ServiceUsageEvent.last
        expect(event.service_instance_guid).to eq(service_instance.guid)
        expect(event.state).to eq('DELETED')
      end

      context 'when there are service bindings' do
        let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
        let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }

        it 'records the service binding delete event' do
          subject.purge(service_instance)

          events              = Event.where(type: 'audit.service_binding.delete').all
          event_binding_guids = events.collect(&:actee)

          expect(events.length).to eq(2)
          expect(event_binding_guids).to match_array([service_binding_1.guid, service_binding_2.guid])
        end

        it 'deletes the service bindings' do
          subject.purge(service_instance)

          expect(service_binding_1).not_to exist
          expect(service_binding_2).not_to exist
        end
      end

      context 'when there are route bindings' do
        let(:route_1) { Route.make(space: service_instance.space) }
        let(:route_2) { Route.make(space: service_instance.space) }
        let!(:route_binding_1) { RouteBinding.make(service_instance: service_instance, route: route_1) }
        let!(:route_binding_2) { RouteBinding.make(service_instance: service_instance, route: route_2) }

        it 'records the service binding delete event' do
          subject.purge(service_instance)

          events              = Event.where(type: 'audit.service_route_binding.delete').all
          event_binding_guids = events.collect(&:actee)

          expect(events.length).to eq(2)
          expect(event_binding_guids).to match_array([route_binding_1.guid, route_binding_2.guid])
        end

        it 'deletes the route bindings' do
          subject.purge(service_instance)

          expect(route_binding_1).not_to exist
          expect(route_binding_2).not_to exist
        end
      end
    end

    describe '#purge' do
      context 'managed service instance' do
        let(:service_instance) { ManagedServiceInstance.make(:routing) }

        it_behaves_like 'delete service instance'

        context 'when there are service keys' do
          let!(:service_key_1) { ServiceKey.make(service_instance: service_instance) }
          let!(:service_key_2) { ServiceKey.make(service_instance: service_instance) }

          it 'records the service key delete event' do
            subject.purge(service_instance)

            events          = Event.where(type: 'audit.service_key.delete').all
            event_key_guids = events.collect(&:actee)

            expect(events.length).to eq(2)
            expect(event_key_guids).to match_array([service_key_1.guid, service_key_2.guid])
          end

          it 'deletes the service keys' do
            subject.purge(service_instance)

            expect(service_key_1).not_to exist
            expect(service_key_2).not_to exist
          end
        end

        context 'when the service instance has shared spaces' do
          let(:target_space) { Space.make }

          before { service_instance.add_shared_space(target_space) }

          it 'records an unshare service event' do
            subject.purge(service_instance)

            events = Event.where(type: 'audit.service_instance.unshare').all
            event_key_guid = events.collect(&:actee)

            expect(events.length).to eq(1)
            expect(event_key_guid).to match_array([service_instance.guid])
          end
        end
      end

      context 'user provided service instance' do
        let(:service_instance) do
          si = UserProvidedServiceInstance.make(:routing)
          si.service_instance_operation = VCAP::CloudController::ServiceInstanceOperation.make(type: 'create', state: 'succeeded')
          si
        end

        it_behaves_like 'delete service instance'
      end
    end
  end
end
