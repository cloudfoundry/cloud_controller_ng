require 'spec_helper'

module VCAP::Services::ServiceBrokers
  RSpec.describe ServiceBrokerRemover do
    subject(:remover) { ServiceBrokerRemover.new(services_events_repository) }
    let(:services_events_repository) { VCAP::CloudController::Repositories::ServiceEventRepository.new(user: user, user_email: email) }
    let(:broker) { VCAP::CloudController::ServiceBroker.make }
    let(:dashboard_client_manager) { instance_double(VCAP::Services::SSO::DashboardClientManager) }
    let(:security_context) { class_double(VCAP::CloudController::SecurityContext, current_user: user, current_user_email: email) }
    let(:user) { VCAP::CloudController::User.make }
    let(:email) { 'email@example.com' }

    describe '#remove' do
      before do
        allow(VCAP::Services::SSO::DashboardClientManager).to receive(:new).and_return(dashboard_client_manager)
        allow(broker).to receive(:destroy)
        allow(dashboard_client_manager).to receive(:remove_clients_for_broker)
      end

      it 'destroys the broker(s)' do
        remover.remove(broker)

        expect(broker).to have_received(:destroy)
      end

      it 'removes the dashboard clients' do
        remover.remove(broker)

        expect(dashboard_client_manager).to have_received(:remove_clients_for_broker)
      end

      it 'records service and service_plan deletion events' do
        service = VCAP::CloudController::Service.make(service_broker: broker)
        plan = VCAP::CloudController::ServicePlan.make(service: service)

        remover.remove(broker)

        event = VCAP::CloudController::Event.first(type: 'audit.service.delete')
        expect(event.type).to eq('audit.service.delete')
        expect(event.actor_type).to eq('service_broker')
        expect(event.actor).to eq(broker.guid)
        expect(event.actor_name).to eq(broker.name)
        expect(event.timestamp).to be
        expect(event.actee).to eq(service.guid)
        expect(event.actee_type).to eq('service')
        expect(event.actee_name).to eq(service.label)
        expect(event.space_guid).to eq('')
        expect(event.organization_guid).to eq('')
        expect(event.metadata).to be_empty

        event = VCAP::CloudController::Event.first(type: 'audit.service_plan.delete')
        expect(event.type).to eq('audit.service_plan.delete')
        expect(event.actor_type).to eq('service_broker')
        expect(event.actor).to eq(broker.guid)
        expect(event.actor_name).to eq(broker.name)
        expect(event.timestamp).to be
        expect(event.actee).to eq(plan.guid)
        expect(event.actee_type).to eq('service_plan')
        expect(event.actee_name).to eq(plan.name)
        expect(event.space_guid).to eq('')
        expect(event.organization_guid).to eq('')
        expect(event.metadata).to be_empty
      end

      context 'when removing the dashboard clients raises an exception' do
        before do
          allow(dashboard_client_manager).to receive(:remove_clients_for_broker).and_raise('the error')
        end

        it 'reraises the error' do
          expect { remover.remove(broker) }.to raise_error('the error')
        end

        it 'does not delete the broker' do
          allow(broker).to receive(:destroy)

          remover.remove(broker) rescue nil

          expect(broker).not_to have_received(:destroy)
        end
      end
    end
  end
end
