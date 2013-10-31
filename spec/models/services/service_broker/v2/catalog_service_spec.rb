require 'spec_helper'
require 'securerandom'

require 'models/services/service_broker/v2/catalog_service'

module VCAP::CloudController::ServiceBroker::V2
  describe CatalogService do
    describe '#cc_service' do
      let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let(:broker_provided_id) { SecureRandom.uuid }
      let(:catalog_service) do
        described_class.new( service_broker,
          'id' => broker_provided_id,
          'name' => 'service-name',
          'description' => 'service description',
          'bindable' => true,
        )
      end
      context 'when a Service exists with the same service broker and broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(
            unique_id: broker_provided_id,
            service_broker: service_broker
          )
        end

        it 'is that Service' do
          expect(catalog_service.cc_service).to eq(cc_service)
        end
      end

      context 'when a Service exists with a different service broker, but the same broker provided id' do
        let!(:cc_service) do
          VCAP::CloudController::Service.make(unique_id: broker_provided_id)
        end

        it 'is nil' do
          expect(catalog_service.cc_service).to be_nil
        end
      end
    end
  end
end