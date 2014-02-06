require 'spec_helper'
require 'models/services/service_broker_registration'

module VCAP::CloudController
  describe ServiceBrokerRegistration do
    describe '#save' do
      let(:broker) do
        ServiceBroker.new(
          name: 'Cool Broker',
          broker_url: 'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
        )
      end

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
      end

      it 'returns itself' do
        expect(registration.save).to eq(registration)
      end

      it 'creates a service broker' do
        expect {
          registration.save
        }.to change(ServiceBroker, :count).from(0).to(1)

        expect(broker).to eq(ServiceBroker.last)

        expect(broker.name).to eq('Cool Broker')
        expect(broker.broker_url).to eq('http://broker.example.com')
        expect(broker.auth_username).to eq('cc')
        expect(broker.auth_password).to eq('auth1234')
        expect(broker).to be_exists
      end

      it 'fetches the catalog' do
        registration.save

        expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to have_been_requested
      end

      it 'resets errors before saving' do
        registration.broker.name = ''
        expect(registration.save).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
        expect(registration.save).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
      end

      it 'syncs services and plans and creates dashboard clients' do
        catalog = double('catalog', sync_services_and_plans: nil, create_service_dashboard_clients: nil)
        VCAP::CloudController::ServiceBroker::V2::Catalog.stub(:new).and_return(catalog)
        catalog.stub(:valid?).and_return(true)
        registration.save
        expect(catalog).to have_received(:sync_services_and_plans)
        expect(catalog).to have_received(:create_service_dashboard_clients)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:broker) { ServiceBroker.new }
          let(:registration) { ServiceBrokerRegistration.new(broker) }

          it 'returns nil' do
            expect(registration.save).to be_nil
          end

          it 'does not create a new service broker' do
            expect {
              registration.save
            }.to_not change(ServiceBroker, :count)
          end

          it 'does not fetch the catalog' do
            registration.save

            expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to_not have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.save

            expect(registration.errors.on(:name)).to include(:presence)
          end
        end

        context 'because the catalog has errors' do
          let(:error_text) { "error text" }
          before do
            catalog = double('catalog')
            VCAP::CloudController::ServiceBroker::V2::Catalog.stub(:new).and_return(catalog)
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:error_text).and_return(error_text)
          end

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.save }.to raise_error(VCAP::Errors::ServiceBrokerCatalogInvalid, /#{error_text}/)
          end
        end

        context 'because the catalog fetch failed' do
          before { stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(status: 500) }

          it 'raises an error, even though we\'d rather it not' do
            expect {
              registration.save
            }.to raise_error ServiceBroker::V2::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect {
              registration.save rescue nil
            }.to_not change(ServiceBroker, :count)
          end
        end
      end

      context 'when exception is raised during transaction' do
        let(:catalog) { double('catalog') }

        before do
          VCAP::CloudController::ServiceBroker::V2::Catalog.stub(:new).and_return(catalog)
          catalog.stub(:valid?).and_return(true)
          catalog.stub(:create_service_dashboard_clients)
          catalog.stub(:revert_dashboard_clients)
          catalog.stub(:sync_services_and_plans).and_raise(Errors::ServiceBrokerCatalogInvalid.new('omg it broke'))
        end

        context 'when broker already exists' do
          before do
            broker.save
          end

          it 'does not update broker' do
            expect(ServiceBroker.count).to eq(1)
            broker.name = 'Awesome new broker name'

            expect{
              expect { registration.save }.to raise_error(Errors::ServiceBrokerCatalogInvalid)
            }.to change{ServiceBroker.count}.by(0)
            broker.reload

            expect(broker.name).to eq('Cool Broker')
          end
        end

        context 'when broker does not exist' do
          it 'does not save new broker' do
            expect(ServiceBroker.count).to eq(0)
            expect{
              expect { registration.save }.to raise_error(Errors::ServiceBrokerCatalogInvalid)
            }.to change{ServiceBroker.count}.by(0)
          end
        end

      end

      context 'when exception is raised during dashboard client creation' do
        let(:catalog) { double('catalog') }
        before do
          VCAP::CloudController::ServiceBroker::V2::Catalog.stub(:new).and_return(catalog)
          catalog.stub(:valid?).and_return(true)
          catalog.stub(:create_service_dashboard_clients).and_raise
        end

        it 'raises the error and does not create a new service broker' do
          expect {
            expect {registration.save}.to raise_error
          }.to_not change(ServiceBroker, :count)
        end
      end
    end
  end
end
