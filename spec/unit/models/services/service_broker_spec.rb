require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }

    let(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, auth_username: auth_username, auth_password: auth_password) }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :auth_password }
      let(:attr_salt) { :salt }
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :services }

      it 'has associated service_plans' do
        service = Service.make(:v2)
        service_plan = ServicePlan.make(service: service)
        service_broker = service.service_broker
        expect(service_broker.service_plans).to include(service_plan)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :broker_url }
      it { is_expected.to validate_presence :auth_username }
      it { is_expected.to validate_presence :auth_password }
      it { is_expected.to validate_uniqueness :name }
      it { is_expected.to validate_uniqueness :broker_url }

      it 'validates the url is a valid http/https url' do
        expect(broker).to be_valid

        broker.broker_url = '127.0.0.1/api'
        expect(broker).to_not be_valid

        broker.broker_url = 'ftp://127.0.0.1/api'
        expect(broker).to_not be_valid

        broker.broker_url = 'http://127.0.0.1/api'
        expect(broker).to be_valid

        broker.broker_url = 'https://127.0.0.1/api'
        expect(broker).to be_valid
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :broker_url, :auth_username }
      it { is_expected.to import_attributes :name, :broker_url, :auth_username, :auth_password }
    end

    describe '#client' do
      it 'returns a client created with the correct arguments' do
        v2_client = double('client')
        expect(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).with(url: broker_url, auth_username: auth_username, auth_password: auth_password).and_return(v2_client)
        expect(broker.client).to be(v2_client)
      end
    end

    describe '#destroy' do
      let(:service_broker) { ServiceBroker.make }

      it 'destroys all services associated with the broker' do
        service = Service.make(service_broker: service_broker)
        expect {
          begin
            service_broker.destroy
          rescue Sequel::ForeignKeyConstraintViolation
          end
        }.to change {
          Service.where(id: service.id).any?
        }.to(false)
      end

      context 'when a service instance exists' do
        it 'does not allow the broker to be destroyed' do
          service = Service.make(service_broker: service_broker)
          service_plan = ServicePlan.make(service: service)
          ManagedServiceInstance.make(service_plan: service_plan)
          expect {
            begin
              service_broker.destroy
            rescue Sequel::ForeignKeyConstraintViolation
            end
          }.to_not change {
            Service.where(id: service.id).count
          }
        end
      end

      context 'when associated with a dashboard client' do
        before do
          ServiceDashboardClient.claim_client_for_broker('some-uaa-id', service_broker)
        end

        it 'successfully destroys the broker' do
          expect { service_broker.destroy }.
            to change(ServiceBroker, :count).by(-1)
        end

        it 'sets the broker_id of the dashboard client to nil' do
          client = ServiceDashboardClient.find_clients_claimed_by_broker(service_broker).first
          expect(client.service_broker_id).to eq(service_broker.id)
          service_broker.destroy
          expect(client.reload.service_broker_id).to be_nil
        end
      end
    end
  end
end
