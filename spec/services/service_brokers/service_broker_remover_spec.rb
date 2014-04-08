require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceBrokerRemover do
    subject(:remover) { ServiceBrokerRemover.new(broker) }
    let(:broker) { VCAP::CloudController::ServiceBroker.make }
    let(:changeset_command) { VCAP::Services::UAA::DeleteClientCommand.new('client-id') }
    let(:client_manager) { double(:client_manager) }

    describe '#execute!' do
      before do
        allow(VCAP::Services::UAA::UaaClientManager).to receive(:new).and_return(client_manager)
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:find_clients_claimed_by_broker)
        allow_any_instance_of(ServiceDashboardClientDiffer).to receive(:create_changeset).
          and_return([changeset_command])
        allow(client_manager).to receive(:modify_transaction)
      end

      it 'destroys the broker' do
        allow(broker).to receive(:destroy)

        remover.execute!

        expect(broker).to have_received(:destroy)
      end

      it 'makes a transaction request to UAA' do
        remover.execute!

        expect(client_manager).to have_received(:modify_transaction).with([changeset_command])
      end

      it 'applies the db action for each command in the changeset' do
        allow(changeset_command).to receive(:db_command)

        remover.execute!

        expect(changeset_command).to have_received(:db_command)
      end

      context 'when the UAA request fails' do
        before do
          error = VCAP::Services::UAA::UaaError.new('error message')
          allow(client_manager).to receive(:modify_transaction).and_raise(error)
        end

        it 'raises a ServiceBrokerDashboardClientFailure error' do
          expect{ remover.execute! }.to raise_error(VCAP::Errors::ApiError) do |err|
            expect(err.name).to eq('ServiceBrokerDashboardClientFailure')
            expect(err.message).to eq('error message')
          end
        end

        it 'does not delete the broker' do
          allow(broker).to receive(:destroy)
          
          remover.execute! rescue nil

          expect(broker).not_to have_received(:destroy)
        end

        it 'does not removed the claim' do
          client_id = changeset_command.client_attrs['id']

          puts client_id

          VCAP::CloudController::ServiceDashboardClient.new(
            uaa_id: client_id,
            service_broker: nil
          ).save

          remover.execute! rescue nil

          dashboard_client = VCAP::CloudController::ServiceDashboardClient.find(uaa_id: client_id)
          expect(dashboard_client).to_not be_nil
        end
      end

      context 'when removing CC claims raises an exception' do
        before do
          allow(changeset_command).to receive(:db_command).and_raise
        end

        it 'reraises the error' do
          expect { remover.execute! }.to raise_error
        end

        it 'does not delete the broker' do
          allow(broker).to receive(:destroy)

          remover.execute! rescue nil

          expect(broker).not_to have_received(:destroy)
        end

        it 'does not make the transaction request to UAA' do
          remover.execute! rescue nil
          expect(client_manager).to_not have_received(:modify_transaction)
        end
      end
    end
  end
end
