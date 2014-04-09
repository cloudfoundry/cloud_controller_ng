require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceBrokerRemover do
    subject(:remover) { ServiceBrokerRemover.new(broker) }
    let(:broker) { VCAP::CloudController::ServiceBroker.make }
    let(:dashboard_client_manager) { double(:client_manager) }

    describe '#execute!' do
      before do
        allow(remover).to receive(:client_manager).and_return(dashboard_client_manager)
        allow(broker).to receive(:destroy)
        allow(dashboard_client_manager).to receive(:remove_clients_for_broker)
      end

      it 'destroys the broker' do
        remover.execute!

        expect(broker).to have_received(:destroy)
      end

      it 'removes the dashboard clients' do
        remover.execute!

        expect(dashboard_client_manager).to have_received(:remove_clients_for_broker)
      end

      context 'when removing the dashboard clients raises an exception' do
        before do
          allow(dashboard_client_manager).to receive(:remove_clients_for_broker).and_raise("the error")
        end

        it 'reraises the error' do
          expect { remover.execute! }.to raise_error("the error")
        end

        it 'does not delete the broker' do
          allow(broker).to receive(:destroy)

          remover.execute! rescue nil

          expect(broker).not_to have_received(:destroy)
        end
      end
    end
  end
end
