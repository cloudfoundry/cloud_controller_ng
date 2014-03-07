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
        manager = ServiceDashboardClientManager.new(catalog, service_broker)
        expect(manager.catalog).to eql(catalog)
      end

      it 'sets the service_broker' do
        manager = ServiceDashboardClientManager.new(catalog, service_broker)
        expect(manager.service_broker).to eql(service_broker)
      end
    end

    describe '#synchronize_clients' do
      let(:manager) { ServiceDashboardClientManager.new(catalog, service_broker) }
      let(:client_manager) { double('client_manager') }

      before do
        allow(catalog).to receive(:error_text)
        allow(client_manager).to receive(:create)
        allow(UaaClientManager).to receive(:new).and_return(client_manager)
        allow(client_manager).to receive(:get_clients).and_return([])
        #allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_service)
        #allow(VCAP::CloudController::ServiceDashboardClient).to receive(:client_claimed_by_service?).
        #  and_return(false)
      end

      it 'checks if uaa clients exist for all services' do
        manager.synchronize_clients

        expect(client_manager).to have_received(:get_clients).with([dashboard_client_attrs_1['id'], dashboard_client_attrs_2['id']])
      end

      context 'when no dashboard sso clients present in the catalog exist in UAA' do
        before do
          allow(client_manager).to receive(:get_clients).and_return([])
        end

        it 'creates clients only for all services that specify dashboard_client' do
          manager.synchronize_clients

          expect(client_manager).to have_received(:create).twice # don't call create for the service without dashboard_client
          expect(client_manager).to have_received(:create).with(dashboard_client_attrs_1)
          expect(client_manager).to have_received(:create).with(dashboard_client_attrs_2)
        end

        it 'returns true' do
          expect(manager.synchronize_clients).to eq(true)
        end

        it 'claims the uaa clients for the services' do
          pending 'completed implementation of catalog update'
          manager.synchronize_clients

          expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_service).
            with(dashboard_client_attrs_1['id'], catalog_service_1.broker_provided_id)
          expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_service).
            with(dashboard_client_attrs_2['id'], catalog_service_2.broker_provided_id)
        end
      end

      context 'when some, but not all dashboard sso clients exist in UAA' do
        before do
          allow(client_manager).to receive(:get_clients).and_return([{'client_id' => catalog_service_1.dashboard_client['id']}])
        end

        context 'when the service exists in CC and it has already claimed the requested UAA client' do
          before do
            pending 'completed implementation of catalog update'
            allow(VCAP::CloudController::ServiceDashboardClient).to receive(:client_claimed_by_service?).
              with(catalog_service_1.dashboard_client['id'], catalog_service_1.broker_provided_id).
              and_return(true)
          end

          it "creates the clients that don't currently exist" do
            manager.synchronize_clients

            expect(client_manager).to have_received(:create).with(dashboard_client_attrs_2)
          end

          it 'does not create the client that is already in uaa' do
            manager.synchronize_clients

            expect(client_manager).to_not have_received(:create).with(dashboard_client_attrs_1)
          end

          it 'returns true' do
            expect(manager.synchronize_clients).to eq(true)
          end

          it 'claims the new uaa client for the service' do
            manager.synchronize_clients

            expect(VCAP::CloudController::ServiceDashboardClient).to have_received(:claim_client_for_service).
              with(dashboard_client_attrs_2['id'], catalog_service_2.broker_provided_id)
            expect(VCAP::CloudController::ServiceDashboardClient).not_to have_received(:claim_client_for_service).
              with(dashboard_client_attrs_1['id'], catalog_service_1.broker_provided_id)
          end
        end

        context 'when the service has not claimed the UAA client' do
          before do
            #allow(VCAP::CloudController::ServiceDashboardClient).to receive(:client_claimed_by_service?).
            #  and_return(false)
          end

          it 'does not create any uaa clients' do
            manager.synchronize_clients

            expect(client_manager).to_not have_received(:create)
          end

          it 'returns false' do
            expect(manager.synchronize_clients).to eq(false)
          end

          it 'has errors for the service' do
            manager.synchronize_clients

            expect(manager.errors.for(catalog_service_1)).not_to be_empty
          end

          it 'does not claim any UAA clients' do
            pending 'completed implementation of catalog update'

            manager.synchronize_clients

            expect(VCAP::CloudController::ServiceDashboardClient).not_to have_received(:claim_client_for_service)
          end
        end
      end
    end
  end
end
