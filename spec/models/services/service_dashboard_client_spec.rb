require 'spec_helper'

module VCAP::CloudController
  describe ServiceDashboardClient do
    let(:claiming_service_id) { 'claiming_service_id' }

    describe '.client_claimed_by_service?' do
      before do
        ServiceDashboardClient.make(
        uaa_id: claimed_uaa_id,
          service_id_on_broker: claiming_service_id,
        )
      end
      let(:claimed_uaa_id) { 'claimed_client_id' }
      let(:other_service_id) { 'a_different_service_id' }

      context 'when service has claimed the client' do
        it 'returns true' do
          expect(ServiceDashboardClient.client_claimed_by_service?(claimed_uaa_id, claiming_service_id)).to be_true
        end
      end

      context 'when a different service has claimed the client' do
        it 'returns false' do
          expect(ServiceDashboardClient.client_claimed_by_service?(claimed_uaa_id, other_service_id)).to be_false
        end
      end

      context 'when the service has claimed a different client' do
        it 'returns false' do
          expect(ServiceDashboardClient.client_claimed_by_service?('a_different_client_id', claiming_service_id)).to be_false
        end
      end
    end

    describe '.claim_client_for_service' do
      let(:uaa_id) { 'client_id' }

      context 'when the client is unclaimed' do
        it 'claims the client for the service' do
          expect {
            ServiceDashboardClient.claim_client_for_service(uaa_id, claiming_service_id)
          }.to change {
            ServiceDashboardClient.client_claimed_by_service?(uaa_id, claiming_service_id)
          }.to(true)
        end
      end

      context 'when the client is already claimed' do
        before do
          ServiceDashboardClient.claim_client_for_service(uaa_id, 'a_different_service')
        end

        it 'raises an exception' do
          expect {
            ServiceDashboardClient.claim_client_for_service(claimed_uaa_id, claiming_service_id)
          }.to raise_exception
        end
      end

      context 'when the service has already claimed a client' do
        before do
          ServiceDashboardClient.claim_client_for_service('a_different_client', claiming_service_id)
        end

        it 'raises an exception' do
          expect {
            ServiceDashboardClient.claim_client_for_service(claimed_uaa_id, claiming_service_id)
          }.to raise_exception
        end
      end

    end

    describe 'validation' do
      context 'when all fields are valid' do
        let(:client) { ServiceDashboardClient.make_unsaved }

        it 'is valid' do
          expect(client).to be_valid
        end
      end

      context 'when the uaa id is nil' do
        let(:client_without_uaa_id) { ServiceDashboardClient.make_unsaved(uaa_id: nil) }
        it 'is not valid' do
          expect(client_without_uaa_id).not_to be_valid
        end
      end

      context 'when the uaa id is blank' do
        let(:client_without_uaa_id) { ServiceDashboardClient.make_unsaved(uaa_id: '') }
        it 'is not valid' do
          expect(client_without_uaa_id).not_to be_valid
        end
      end

      context 'when the uaa id is not unique' do
        before { ServiceDashboardClient.make(uaa_id: 'already_taken') }
        let(:client_with_duplicate_uaa_id) { ServiceDashboardClient.make_unsaved(uaa_id: 'already_taken') }

        it 'is not valid' do
          expect(client_with_duplicate_uaa_id).not_to be_valid
        end
      end

      context "when the service's id on the broker is nil" do
        let(:client_without_service_id_on_broker) { ServiceDashboardClient.make_unsaved(service_id_on_broker: nil) }
        it 'is not valid' do
          expect(client_without_service_id_on_broker).not_to be_valid
        end
      end

      context "when the service's id on the broker is blank" do
        let(:client_without_service_id_on_broker) { ServiceDashboardClient.make_unsaved(service_id_on_broker: '') }
        it 'is not valid' do
          expect(client_without_service_id_on_broker).not_to be_valid
        end
      end

      context 'when another client exists with the same service id' do
        before { ServiceDashboardClient.make(service_id_on_broker: service_id_on_broker) }
        let(:service_id_on_broker) { 'serviceidonbroker' }
        let(:client_with_duplicate_service_id_on_broker) { ServiceDashboardClient.make_unsaved(service_id_on_broker: service_id_on_broker) }

        it 'is not valid' do
          expect(client_with_duplicate_service_id_on_broker).not_to be_valid
        end
      end
    end
  end
end
