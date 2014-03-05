require 'spec_helper'

module VCAP::CloudController::ServiceBrokers::V2
  describe ServiceDashboardClientManager do
    let(:dashboard_client_attrs_1) do
      {
        'id'           => 'abcde123',
        'secret'       => 'sekret',
        'redirect_uri' => 'http://example.com'
      }
    end
    let(:dashboard_client_attrs_2) do
      {
        'id'           => 'fghijk456',
        'secret'       => 'differentsekret',
        'redirect_uri' => 'http://example.com/somethingelse'
      }
    end
    let(:service_broker) { VCAP::CloudController::ServiceBroker.make }
    let(:catalog_service_1) {
      CatalogService.new(service_broker,
        'id'               => 'f8ccf75f-4552-4143-97ea-24ccca5ad068',
        'dashboard_client' => dashboard_client_attrs_1,
        'name'             => 'service-1',
      )
    }
    let(:catalog_service_2) {
      CatalogService.new(service_broker,
        'id'               => '0489055c-97b8-4754-8221-c69375ddb33b',
        'dashboard_client' => dashboard_client_attrs_2,
        'name'             => 'service-2',
      )
    }
    let(:catalog_service_without_dashboard_client) {
      CatalogService.new(service_broker,
        'id'               => '4b6088af-cdc4-4ee2-8292-9fa93af32fc8',
        'name'             => 'service-3',
      )
    }

    let(:catalog_services) { [catalog_service_1, catalog_service_2, catalog_service_without_dashboard_client] }

    let(:catalog) { double(:catalog, services: catalog_services) }

    describe '#initialize' do
      it 'sets the catalog' do
        manager = ServiceDashboardClientManager.new(catalog)
        expect(manager.catalog).to eql(catalog)
      end
    end

    describe '#create_service_dashboard_clients' do
      let(:manager) { ServiceDashboardClientManager.new(catalog) }
      let(:client_manager) { double('client_manager') }

      before do
        allow(catalog).to receive(:error_text)
        allow(client_manager).to receive(:create)
        allow(UaaClientManager).to receive(:new).and_return(client_manager)
        allow(client_manager).to receive(:get_clients).and_return([])
      end

      it 'checks if uaa clients exist for all services' do
        manager.create_service_dashboard_clients

        expect(client_manager).to have_received(:get_clients).with([dashboard_client_attrs_1['id'], dashboard_client_attrs_2['id']])
      end

      context 'when no dashboard sso clients present in the catalog exist in UAA' do
        before do
          allow(client_manager).to receive(:get_clients).and_return([])
        end

        it 'creates clients only for all services that specify dashboard_client' do
          manager.create_service_dashboard_clients

          expect(client_manager).to have_received(:create).twice # don't call create for the service without dashboard_client
          expect(client_manager).to have_received(:create).with(dashboard_client_attrs_1)
          expect(client_manager).to have_received(:create).with(dashboard_client_attrs_2)
        end

        it 'returns true' do
          expect(manager.create_service_dashboard_clients).to eq(true)
        end
      end

      context 'when some, but not all dashboard sso clients exist in UAA' do
        before do
          allow(client_manager).to receive(:get_clients).and_return([{'client_id' => catalog_service_1.dashboard_client['id']}])
        end

        context 'when the service exists in CC and it has already claimed the requested UAA client' do
          before do
            VCAP::CloudController::Service.make(service_broker: service_broker, unique_id: catalog_service_1.broker_provided_id, sso_client_id: catalog_service_1.dashboard_client['id'])
          end

          it "creates the clients that don't currently exist" do
            manager.create_service_dashboard_clients

            expect(client_manager).to have_received(:create).with(dashboard_client_attrs_2)
          end

          it 'does not create the client that is already in uaa' do
            manager.create_service_dashboard_clients

            expect(client_manager).to_not have_received(:create).with(dashboard_client_attrs_1)
          end

          it 'returns true' do
            expect(manager.create_service_dashboard_clients).to eq(true)
          end
        end

        context 'when another service in CC has already claimed the requested UAA client' do
          before do
            VCAP::CloudController::Service.make(service_broker: service_broker, sso_client_id: catalog_service_1.dashboard_client['id'])
          end

          it 'does not create any uaa clients' do
            manager.create_service_dashboard_clients

            expect(client_manager).to_not have_received(:create)
          end

          it 'returns false' do
            expect(manager.create_service_dashboard_clients).to eq(false)
          end

          it 'has errors for the service' do
            manager.create_service_dashboard_clients

            expect(manager.errors.for(catalog_service_1)).not_to be_empty
          end
        end

        context 'when the requested UAA client exists, but was not created by CC' do
          it 'does not create any uaa clients' do
            manager.create_service_dashboard_clients rescue nil

            expect(client_manager).to_not have_received(:create)
          end

          it 'returns false' do
            expect(manager.create_service_dashboard_clients).to eq(false)
          end

          it 'has errors for the service' do
            manager.create_service_dashboard_clients

            expect(manager.errors.for(catalog_service_1)).not_to be_empty
          end
        end
      end
    end
  end
end
