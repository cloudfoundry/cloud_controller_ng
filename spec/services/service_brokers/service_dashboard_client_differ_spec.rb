require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceDashboardClientDiffer do
    describe '.create_changeset' do
      let(:service_broker) { double(:service_broker, id: 'service-broker-1') }
      let(:dashboard_client) do
        {
          'id' => 'client-id-1',
          'secret' => 'sekret',
          'redirect_uri' => 'https://foo.com'
        }
      end
      let(:differ) { ServiceDashboardClientDiffer.new(service_broker) }

      subject(:changeset) { differ.create_changeset(requested_clients, existing_cc_clients, existing_uaa_clients) }

      context 'when there is a non-existing client requested' do
        let(:requested_clients) { [dashboard_client] }
        let(:existing_cc_clients) { [] }
        let(:existing_uaa_clients) { [] }

        it 'returns a create command' do
          expect(changeset).to have(1).items
          expect(changeset.first).to be_a VCAP::Services::UAA::CreateClientCommand
          expect(changeset.first.client_attrs).to eq(dashboard_client)
          expect(changeset.first.service_broker).to eq(service_broker)
        end
      end

      context 'when a requested client exists in cc' do
        let(:requested_clients) { [dashboard_client] }
        let(:existing_cc_clients) do
          [
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: dashboard_client['id']
            )
          ]
        end

        context 'and it also exists in uaa' do
          let(:existing_uaa_clients) { [dashboard_client['id']] }

          it 'returns update commands for the existing clients' do
            expect(changeset).to have(1).items
            expect(changeset.first).to be_a VCAP::Services::UAA::UpdateClientCommand
            expect(changeset.first.client_attrs).to eq(dashboard_client)
            expect(changeset.first.service_broker).to eq(service_broker)
          end
        end

        context 'and it does not exist in uaa' do
          let(:existing_uaa_clients) { [] }

          it 'returns a create command' do
            expect(changeset).to have(1).items
            expect(changeset.first).to be_a VCAP::Services::UAA::CreateClientCommand
            expect(changeset.first.client_attrs).to eq(dashboard_client)
            expect(changeset.first.service_broker).to eq(service_broker)
          end
        end
      end

      context 'when a claimed client is removed from the catalog' do
        let(:requested_clients) { [] }
        let(:existing_cc_clients) do
          [
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: dashboard_client['id']
            )
          ]
        end
        let(:existing_uaa_clients) { [dashboard_client['id']] }

        it 'returns a delete command for the existing client' do
          expect(changeset).to have(1).items
          expect(changeset.first).to be_a VCAP::Services::UAA::DeleteClientCommand
          expect(changeset.first.client_id).to eq(dashboard_client['id'])
        end
      end
      
      context 'when the catalog requests to create a new client, update an existing one, and delete an old one' do
        let(:new_client) { dashboard_client }
        let(:new_client_2) do
          dashboard_client.merge('id' => 'client-id-4')
        end
        let(:existing_client) do
          {
            'id' => 'client-id-2',
            'secret' => 'sekret2',
            'redirect_uri' => 'https://foo2.com'
          }
        end
        let(:existing_client_2) do
          {
            'id' => 'client-id-5',
            'secret' => 'sekret2',
            'redirect_uri' => 'https://foo2.com'
          }
        end

        let(:requested_clients) do
          [
            new_client,
            existing_client,
            new_client_2,
            existing_client_2,
          ]
        end

        let(:existing_cc_clients) do
          [
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: existing_client['id']
            ),
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: 'will-be-deleted'
            ),
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: existing_client_2['id']
            ),
            double(:client,
              service_id_on_broker: service_broker.id,
              uaa_id: 'will-be-deleted-2'
            )
          ]
        end

        let(:existing_uaa_clients) do
          [
            existing_client['id'],
           'will-be-deleted',
           existing_client_2['id'],
           'will-be-deleted-2'
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
