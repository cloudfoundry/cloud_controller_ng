require 'spec_helper'

module VCAP::Services::ServiceBrokers
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
    let(:catalog_service) {
      V2::CatalogService.new(service_broker,
        'id'               => 'f8ccf75f-4552-4143-97ea-24ccca5ad068',
        'dashboard_client' => dashboard_client_attrs_1,
        'name'             => 'service-1',
      )
    }
    let(:catalog_service_2) {
      V2::CatalogService.new(service_broker,
        'id'               => '0489055c-97b8-4754-8221-c69375ddb33b',
        'dashboard_client' => dashboard_client_attrs_2,
        'name'             => 'service-2',
      )
    }
    let(:catalog_service_without_dashboard_client) {
      V2::CatalogService.new(service_broker,
        'id'               => '4b6088af-cdc4-4ee2-8292-9fa93af32fc8',
        'name'             => 'service-3',
      )
    }

    let(:catalog_services) { [catalog_service, catalog_service_2, catalog_service_without_dashboard_client] }

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
        allow(VCAP::Services::UAA::UaaClientManager).to receive(:new).and_return(client_manager)
        allow(client_manager).to receive(:get_clients).and_return([])
        allow(client_manager).to receive(:modify_transaction)
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
          expect(client_manager).to receive(:modify_transaction) do |changeset|
            expect(changeset.length).to eq 2
            expect(changeset.all? {|change| change.is_a? VCAP::Services::UAA::CreateClientCommand}).to be_true
            expect(changeset[0].client_attrs).to eq dashboard_client_attrs_1
            expect(changeset[1].client_attrs).to eq dashboard_client_attrs_2
          end

          manager.synchronize_clients
        end

        it 'claims the clients' do
          expect {
            manager.synchronize_clients
          }.to change { VCAP::CloudController::ServiceDashboardClient.count }.by 2

          expect(VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_1['id'])).to_not be_nil
          expect(VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_2['id'])).to_not be_nil
        end

        it 'returns true' do
          expect(manager.synchronize_clients).to eq(true)
        end
      end

      context 'when some, but not all dashboard sso clients exist in UAA' do
        before do
          allow(client_manager).to receive(:get_clients).and_return([{'client_id' => catalog_service.dashboard_client['id']}])
        end

        context 'when the service exists in CC and it has already claimed the requested UAA client' do
          let(:dashboard_client) do
            VCAP::CloudController::ServiceDashboardClient.new(
              uaa_id: dashboard_client_attrs_1['id'],
              service_broker: service_broker
            ).save
          end

          before do
            allow(VCAP::CloudController::ServiceDashboardClient).to receive(:client_can_be_claimed_by_broker?).
              with(catalog_service.dashboard_client['id'], service_broker).
              and_return(true)
            allow(VCAP::CloudController::ServiceDashboardClient).to receive(:find_client_by_uaa_id).
              with(dashboard_client_attrs_1['id']).
              and_return(dashboard_client)
          end

          it 'creates the clients that do not currently exist' do
            expect(client_manager).to receive(:modify_transaction) do |changeset|
              create_commands = changeset.select { |command| command.is_a? VCAP::Services::UAA::CreateClientCommand}
              expect(create_commands.length).to eq 1
              expect(create_commands[0].client_attrs).to eq dashboard_client_attrs_2
            end

            manager.synchronize_clients
          end

          it 'updates the client that is already in uaa' do
            expect(client_manager).to receive(:modify_transaction) do |changeset|
              update_commands = changeset.select { |command| command.is_a? VCAP::Services::UAA::UpdateClientCommand}
              expect(update_commands.length).to eq 1
              expect(update_commands[0].client_attrs).to eq dashboard_client_attrs_1
            end

            manager.synchronize_clients
          end

          it 'claims the clients' do
            expect {
              manager.synchronize_clients
            }.to change { VCAP::CloudController::ServiceDashboardClient.count }.by 1

            expect(VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_1['id'])).to_not be_nil
            expect(VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_2['id'])).to_not be_nil
          end

          it 'returns true' do
            expect(manager.synchronize_clients).to eq(true)
          end
        end

        context 'when the service has not claimed the existing UAA client' do
          it 'does not create any uaa clients' do
            manager.synchronize_clients

            expect(client_manager).to_not have_received(:modify_transaction)
          end

          it 'does not claim any clients for CC' do
            expect(VCAP::CloudController::ServiceDashboardClient.count).to eq(0)
            expect { manager.synchronize_clients }.not_to change{ VCAP::CloudController::ServiceDashboardClient.count }
          end

          it 'returns false' do
            expect(manager.synchronize_clients).to eq(false)
          end

          it 'has errors for the service' do
            manager.synchronize_clients

            expect(manager.errors.for(catalog_service)).not_to be_empty
          end
        end
      end

      context 'when the UAA has clients claimed by CC that are no longer used by a service' do
        let(:unused_id) { 'no-longer-used' }
        let(:catalog) { double(:catalog, services: []) }

        before do
          allow(client_manager).to receive(:get_clients).and_return([{'client_id' => unused_id}])

          VCAP::CloudController::ServiceDashboardClient.new(
            uaa_id: unused_id,
            service_broker: service_broker
          ).save
        end

        it 'deletes the client from the uaa' do
          expect(client_manager).to receive(:modify_transaction) do |changeset|
            delete_commands = changeset.select { |command| command.is_a? VCAP::Services::UAA::DeleteClientCommand}
            expect(delete_commands.length).to eq 1
            expect(delete_commands[0].client_id).to eq(unused_id)
          end

          manager.synchronize_clients
        end

        it 'removes the claims for the deleted clients' do
          manager.synchronize_clients
          expect(VCAP::CloudController::ServiceDashboardClient.find(uaa_id: unused_id)).to be_nil
        end

        it 'returns true' do
          expect(manager.synchronize_clients).to be_true
        end
      end

      context 'when modifying UAA clients fails' do
        let(:unused_id) { 'no-longer-used' }

        before do
          allow(client_manager).to receive(:get_clients).and_return([{'client_id' => unused_id}])
          allow(client_manager).to receive(:modify_transaction).and_raise(VCAP::Services::UAA::UaaError.new('error message'))
        end

        it 'does not add new claims' do
          manager.synchronize_clients rescue nil

          dashboard_client = VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_1['id'])
          expect(dashboard_client).to be_nil
        end

        it 'does not delete existing claims' do
          VCAP::CloudController::ServiceDashboardClient.new(
            uaa_id: unused_id,
            service_broker: service_broker
          ).save

          manager.synchronize_clients rescue nil

          dashboard_client = VCAP::CloudController::ServiceDashboardClient.find(uaa_id: unused_id)
          expect(dashboard_client).to_not be_nil
        end

        it 'does not modify any of the claims' do
          VCAP::CloudController::ServiceDashboardClient.new(
            uaa_id: dashboard_client_attrs_2['id'],
            service_broker: nil
          ).save

          manager.synchronize_clients rescue nil

          dashboard_client = VCAP::CloudController::ServiceDashboardClient.find(uaa_id: dashboard_client_attrs_2['id'])
          expect(dashboard_client.service_broker).to be_nil
        end

        it 'raises a ServiceBrokerDashboardClientFailure error' do
          expect{ manager.synchronize_clients }.to raise_error(VCAP::Errors::ApiError) do |err|
            expect(err.name).to eq('ServiceBrokerDashboardClientFailure')
            expect(err.message).to eq('error message')
          end
        end
      end

      context 'when claiming the client for the broker fails' do
        before do
          allow(VCAP::CloudController::ServiceDashboardClient).to receive(:claim_client_for_broker).and_raise
        end

        it 'does not modify the UAA client' do
          manager.synchronize_clients rescue nil
          expect(client_manager).to_not have_received(:modify_transaction)
        end
      end

      context 'when the cloud controller is not configured to modify sso_client' do
        before do
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(:uaa_client_name).and_return nil
          allow(VCAP::CloudController::Config.config).to receive(:[]).with(:uaa_client_secret).and_return nil
          allow(client_manager).to receive(:modify_transaction)
        end

        it 'does not create/update/delete any clients' do
          manager.synchronize_clients
          expect(client_manager).not_to have_received(:modify_transaction)
        end

        it 'returns true' do
          expect(manager.synchronize_clients).to be_true
        end
      end
    end
  end
end
