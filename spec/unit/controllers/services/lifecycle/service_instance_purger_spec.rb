require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::ServiceInstancePurger do
    let(:event_repository) { VCAP::CloudController::Repositories::Services::EventRepository.new({ user: User.make, user_email: 'email' }) }
    let(:purger) { ServiceInstancePurger.new(event_repository) }

    describe '#purge' do
      let(:service_instance) { ManagedServiceInstance.make }

      it 'records a service instance delete event' do
        purger.purge(service_instance)

        event = Event.last
        expect(event.type).to eq('audit.service_instance.delete')
        expect(event.actee).to eq(service_instance.guid)
      end

      it 'records a service usage event for DELETED' do
        purger.purge(service_instance)

        event = ServiceUsageEvent.last
        expect(event.service_instance_guid).to eq(service_instance.guid)
        expect(event.state).to eq('DELETED')
      end

      context 'when there are service bindings' do
        let!(:service_binding_1) { ServiceBinding.make(service_instance: service_instance) }
        let!(:service_binding_2) { ServiceBinding.make(service_instance: service_instance) }

        it 'records a service instance with a service binding delete event' do
          purger.purge(service_instance)

          events              = Event.where(type: 'audit.service_binding.delete').all
          event_binding_guids = events.collect(&:actee)

          expect(events.length).to eq(2)
          expect(event_binding_guids).to match_array([service_binding_1.guid, service_binding_2.guid])
        end
      end

      context 'when there are service keys' do
        let!(:service_key_1) { ServiceKey.make(service_instance: service_instance) }
        let!(:service_key_2) { ServiceKey.make(service_instance: service_instance) }

        it 'records a service instance with a service key delete event' do
          purger.purge(service_instance)

          events          = Event.where(type: 'audit.service_key.delete').all
          event_key_guids = events.collect(&:actee)

          expect(events.length).to eq(2)
          expect(event_key_guids).to match_array([service_key_1.guid, service_key_2.guid])
        end
      end
    end
  end
end
