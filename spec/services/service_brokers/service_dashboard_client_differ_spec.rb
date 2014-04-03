require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceDashboardClientDiffer do
    describe '.create_changeset' do
      let(:uaa_client) { double(:uaa_client) }
      let(:service_broker) { double(:service_broker) }
      let(:catalog_service) do
        V2::CatalogService.new(service_broker, 'dashboard_client' => {
          'id' => 'client-id-1',
          'secret' => 'sekret',
          'redirect_uri' => 'https://foo.com'
        })
      end
      let(:differ) { ServiceDashboardClientDiffer.new(service_broker, uaa_client) }

      subject(:changeset) { differ.create_changeset(services_requesting_clients, existing_clients) }

      context 'when there is a non-existing client requested' do
        let(:services_requesting_clients) { [catalog_service] }
        let(:existing_clients) { [] }
        it 'returns a create command' do
          expect(changeset).to have(1).items
          expect(changeset.first).to be_a VCAP::Services::UAA::CreateClientCommand
          expect(changeset.first.client_attrs).to eq(catalog_service.dashboard_client)
          expect(changeset.first.service_broker).to eq(service_broker)
        end
      end

      context 'when a requested client exists' do
        let(:services_requesting_clients) { [catalog_service] }
        let(:existing_clients) do
          [
            double(:client,
              service_id_on_broker: catalog_service.broker_provided_id,
              uaa_id: catalog_service.dashboard_client['id']
            )
          ]
        end

        it 'returns update commands for the existing clients' do
          expect(changeset).to have(1).items
          expect(changeset.first).to be_a VCAP::Services::UAA::UpdateClientCommand
          expect(changeset.first.client_attrs).to eq(catalog_service.dashboard_client)
          expect(changeset.first.service_broker).to eq(service_broker)
        end
      end

      context 'when a claimed client is removed from the catalog' do
        let(:services_requesting_clients) { [] }
        let(:existing_clients) do
          [
            double(:client,
              service_id_on_broker: catalog_service.broker_provided_id,
              uaa_id: catalog_service.dashboard_client['id']
            )
          ]
        end

        it 'returns a delete command for the existing client' do
          expect(changeset).to have(1).items
          expect(changeset.first).to be_a VCAP::Services::UAA::DeleteClientCommand
          expect(changeset.first.client_id).to eq(catalog_service.dashboard_client['id'])
        end
      end
      
      context 'when the catalog requests to create a new client, update an existing one, and delete an old one' do
        let(:service_with_new_client) { catalog_service }
        let(:service_with_new_client_2) do
          V2::CatalogService.new(service_broker, 'dashboard_client' =>
            catalog_service.dashboard_client.merge('id' => 'client-id-4')
          )
        end
        let(:service_with_existing_client) do
          V2::CatalogService.new(service_broker, 'dashboard_client' => {
            'id' => 'client-id-2',
            'secret' => 'sekret2',
            'redirect_uri' => 'https://foo2.com'
          })
        end
        let(:service_with_existing_client_2) do
          V2::CatalogService.new(service_broker, 'dashboard_client' => {
            'id' => 'client-id-5',
            'secret' => 'sekret2',
            'redirect_uri' => 'https://foo2.com'
          })
        end

        let(:service_with_client_to_be_removed) do
          V2::CatalogService.new(service_broker, {'dashboard_client' => nil })
        end

        let(:service_with_client_to_be_removed_2) do
          V2::CatalogService.new(service_broker, {'dashboard_client' => nil })
        end

        let(:services_requesting_clients) do
          [
            service_with_new_client,
            service_with_existing_client,
            service_with_new_client_2,
            service_with_existing_client_2,
          ]
        end

        let(:existing_clients) do
          [
            double(:client,
              service_id_on_broker: service_with_existing_client.broker_provided_id,
              uaa_id: service_with_existing_client.dashboard_client['id']
            ),
            double(:client,
              service_id_on_broker: service_with_client_to_be_removed.broker_provided_id,
              uaa_id: 'will-be-deleted'
            ),
            double(:client,
              service_id_on_broker: service_with_existing_client_2.broker_provided_id,
              uaa_id: service_with_existing_client_2.dashboard_client['id']
            ),
            double(:client,
              service_id_on_broker: service_with_client_to_be_removed_2.broker_provided_id,
              uaa_id: 'will-be-deleted-2'
            )
          ]
        end

        it 'succeeds to create all the necessary commands' do
          expect(changeset).to have(6).items
          expect(changeset[0]).to be_a VCAP::Services::UAA::CreateClientCommand
          expect(changeset[1]).to be_a VCAP::Services::UAA::UpdateClientCommand
          expect(changeset[2]).to be_a VCAP::Services::UAA::CreateClientCommand
          expect(changeset[3]).to be_a VCAP::Services::UAA::UpdateClientCommand
          expect(changeset[4]).to be_a VCAP::Services::UAA::DeleteClientCommand
          expect(changeset[5]).to be_a VCAP::Services::UAA::DeleteClientCommand
        end
      end
    end
  end
end
