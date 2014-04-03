require 'spec_helper'

module VCAP::CloudController
  describe ServiceBroker, :services, type: :model do
    let(:name) { Sham.name }
    let(:broker_url) { 'http://cf-service-broker.example.com' }
    let(:auth_username) { 'me' }
    let(:auth_password) { 'abc123' }

    subject(:broker) { ServiceBroker.new(name: name, broker_url: broker_url, auth_username: auth_username, auth_password: auth_password) }

    it_behaves_like 'a model with an encrypted attribute' do
      let(:encrypted_attr) { :auth_password }
    end

    describe '#valid?' do
      it 'validates the name is present' do
        expect(broker).to be_valid
        broker.name = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:presence)
      end

      it 'validates the url is present' do
        expect(broker).to be_valid
        broker.broker_url = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:presence)
      end

      it 'validates the auth_username is present' do
        expect(broker).to be_valid
        broker.auth_username = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:auth_username)).to include(:presence)
      end

      it 'validates the auth_password is present' do
        expect(broker).to be_valid
        broker.auth_password = ''
        expect(broker).to_not be_valid
        expect(broker.errors.on(:auth_password)).to include(:presence)
      end

      it 'validates the name is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(name: broker.name)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:name)).to include(:unique)
      end

      it 'validates the url is unique' do
        expect(broker).to be_valid
        ServiceBroker.make(broker_url: broker.broker_url)
        expect(broker).to_not be_valid
        expect(broker.errors.on(:broker_url)).to include(:unique)
      end

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

    describe '#client' do
      it 'returns a client created with the correct arguments' do
        v2_client = double('client')
        VCAP::Services::ServiceBrokers::V2::Client.should_receive(:new).with(url: broker_url, auth_username: auth_username, auth_password: auth_password).and_return(v2_client)
        expect(broker.client).to be(v2_client)
      end
    end

    describe "#destroy" do
      let(:service_broker) { ServiceBroker.make }

      it "destroys all services associated with the broker" do
        service = Service.make(:service_broker => service_broker)
        expect {
          begin
            service_broker.destroy(savepoint: true)
          rescue Sequel::ForeignKeyConstraintViolation
          end
        }.to change {
          Service.where(:id => service.id).any?
        }.to(false)
      end

      context 'when a service instance exists' do
        it 'does not allow the broker to be destroyed' do
          service = Service.make(:service_broker => service_broker)
          service_plan = ServicePlan.make(:service => service)
          ManagedServiceInstance.make(:service_plan => service_plan)
          expect {
            begin
              service_broker.destroy(savepoint: true)
            rescue Sequel::ForeignKeyConstraintViolation
            end
          }.to_not change {
            Service.where(:id => service.id).count
          }.by(-1)
        end
      end

      context 'when associated with a dashboard client' do
        before do
          ServiceDashboardClient.claim_client_for_broker('some-uaa-id', service_broker)
        end

        it 'successfully destroys the broker' do
          expect { service_broker.destroy(savepoint: true) }.
            to change(ServiceBroker, :count).by(-1)
        end

        it 'sets the broker_id of the dashboard client to nil' do
          client = ServiceDashboardClient.find_clients_claimed_by_broker(service_broker).first
          expect(client.service_broker_id).to eq(service_broker.id)
          service_broker.destroy(savepoint: true)
          expect(client.reload.service_broker_id).to be_nil
        end
      end
    end
  end
end
