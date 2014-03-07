require 'spec_helper'
require 'models/services/service_brokers/v2/service_dashboard_client_differ'

module VCAP::CloudController::ServiceBrokers::V2
  describe ServiceDashboardClientDiffer do
    describe '.create_changeset' do
      context 'when none of the requested clients exist' do
        let(:uaa_client) { double(:uaa_client) }
        let(:service_broker) { double(:service_broker) }
        let(:catalog_service_1) do
          CatalogService.new(service_broker, 'dashboard_client' => {
            'id' => 'client-id-1',
            'secret' => 'sekret',
            'redirect_uri' => 'https://foo.com'
          })
        end
        let(:catalog_service_2) do
          CatalogService.new(service_broker, 'dashboard_client' => {
            'id' => 'client-id-2',
            'secret' => 'sekret2',
            'redirect_uri' => 'https://foo2.com'
          })
        end
        it 'returns a create command for each client' do
          changeset = ServiceDashboardClientDiffer.create_changeset([catalog_service_1, catalog_service_2], uaa_client)
          expect(changeset).to have(2).items
          expect(changeset.all?{|command| command.is_a? CreateClientCommand }).to be_true
          expect(changeset[0].dashboard_client).to eq(catalog_service_1.dashboard_client)
          expect(changeset[1].dashboard_client).to eq(catalog_service_2.dashboard_client)
        end
      end
    end
  end
end
