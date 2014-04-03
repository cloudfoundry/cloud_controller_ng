require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceBrokerRemoval do
    subject(:removal) { ServiceBrokerRemoval.new(broker) }
    let(:broker) { double(:broker, destroy: nil) }
    let(:changeset_command) { double(:command, apply!: nil) }

    describe '#execute!' do
      before do
        allow(VCAP::CloudController::ServiceDashboardClient).to receive(:find_clients_claimed_by_broker)
        allow_any_instance_of(ServiceDashboardClientDiffer).to receive(:create_changeset).
          and_return([changeset_command])
      end

      it 'destroys the broker' do
        removal.execute!

        expect(broker).to have_received(:destroy)
      end

      context 'when applying one of the changeset commands raises an exception' do
        before do
          allow(changeset_command).to receive(:apply!).and_raise
        end

        it 'reraises the error' do
          expect { removal.execute! }.to raise_error
        end

        it 'does not delete the broker' do
          removal.execute! rescue nil
          expect(broker).not_to have_received(:destroy)

        end
      end
    end
  end
end
