require 'spec_helper'

module VCAP::Services::ServiceBrokers
  RSpec.describe ServiceBrokerRemover do
    subject(:remover) { ServiceBrokerRemover.new(services_events_repository) }
    let(:services_events_repository) do
      VCAP::CloudController::Repositories::ServiceEventRepository.new(VCAP::CloudController::UserAuditInfo.new(user_guid: user.guid, user_email: email))
    end
    let(:broker) { VCAP::CloudController::ServiceBroker.make }
    let(:dashboard_client_manager) { instance_double(VCAP::Services::SSO::DashboardClientManager) }
    let(:security_context) { class_double(VCAP::CloudController::SecurityContext, current_user: user, current_user_email: email) }
    let(:user) { VCAP::CloudController::User.make }
    let(:email) { 'email@example.com' }

    before do
      allow(VCAP::Services::SSO::DashboardClientManager).to receive(:new).and_return(dashboard_client_manager)
      allow(broker).to receive(:destroy)
      allow(dashboard_client_manager).to receive(:remove_clients_for_broker)
    end

    describe '#delete' do
      let(:brokers) {
        [broker]
      }

      before do
        brokers.each { |b| allow(b).to receive(:destroy) }
      end

      it 'destroys each broker' do
        remover.delete(brokers)

        brokers.each do |b|
          expect(b).to have_received(:destroy)
        end
      end

      it 'removes all dashboard clients' do
        remover.delete(brokers)

        expect(dashboard_client_manager).to have_received(:remove_clients_for_broker)
      end

      it 'records service and service plan deletion events' do
        service = VCAP::CloudController::Service.make(service_broker: broker)
        plan = VCAP::CloudController::ServicePlan.make(service: service)

        remover.delete(brokers)

        expect_events_for_broker(broker, service, plan)
      end

      context 'when the deletion fails' do
        before do
          allow(broker).to receive(:destroy).and_raise('cannot delete!!!')
        end

        it 'sets the state to failed' do
          expect { remover.delete(brokers) }.to raise_error('cannot delete!!!')

          expect(broker.reload.state).to eq(VCAP::CloudController::ServiceBrokerStateEnum::DELETE_FAILED)
        end
      end
    end

    describe '#remove' do
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

        expect_events_for_broker(broker, service, plan)
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

    def expect_events_for_broker(broker, service, plan)
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
  end
end
