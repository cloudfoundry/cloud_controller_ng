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
      let(:manager) { double(:service_dashboard_manager, :create_service_dashboard_clients => true) }
      let(:catalog) { double(:catalog, :sync_services_and_plans => true, :valid? => true)}

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
        allow(ServiceBrokers::V2::ServiceDashboardClientManager).to receive(:new).and_return(manager)
        allow(ServiceBrokers::V2::Catalog).to receive(:new).and_return(catalog)
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

      it 'syncs services and plans' do
        registration.save

        expect(catalog).to have_received(:sync_services_and_plans)
      end

      it 'creates dashboard clients' do
        registration.save

        expect(ServiceBrokers::V2::ServiceDashboardClientManager).to have_received(:new).with(catalog)
        expect(manager).to have_received(:create_service_dashboard_clients)
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
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:error_text).and_return(error_text)
          end

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.save }.to raise_error(VCAP::Errors::ApiError, /#{error_text}/)
          end
        end

        context 'because the catalog fetch failed' do
          before { stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(status: 500) }

          it 'raises an error, even though we\'d rather it not' do
            expect {
              registration.save
            }.to raise_error ServiceBrokers::V2::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect {
              registration.save rescue nil
            }.to_not change(ServiceBroker, :count)
          end
        end

        context 'because the dashboard client manager failed' do
          before do
            allow(manager).to receive(:create_service_dashboard_clients).and_return(false)
            allow(manager).to receive(:errors).and_return(validation_errors)
            allow_any_instance_of(ServiceBrokers::V2::ValidationErrorsFormatter).to receive(:format).and_return(error_text)
          end

          let(:error_text) { 'something bad happened' }
          let(:validation_errors) { double(:validation_errors) }

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.save }.to raise_error(VCAP::Errors::ApiError, /#{error_text}/)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          catalog.stub(:valid?).and_return(true)
          catalog.stub(:sync_services_and_plans).and_raise(Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", 'omg it broke'))
        end

        context 'when broker already exists' do
          before do
            broker.save
          end

          it 'does not update broker' do
            expect(ServiceBroker.count).to eq(1)
            broker.name = 'Awesome new broker name'

            expect{
              begin
                registration.save
              rescue VCAP::Errors::ApiError
              end
            }.to change{ServiceBroker.count}.by(0)
            broker.reload

            expect(broker.name).to eq('Cool Broker')
          end

        end

        context 'when broker does not exist' do
          it 'does not save new broker' do
            expect(ServiceBroker.count).to eq(0)
            expect{
              begin
                registration.save
              rescue VCAP::Errors::ApiError
              end
            }.to change{ServiceBroker.count}.by(0)
          end
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          catalog.stub(:valid?).and_return(true)
          manager.stub(:create_service_dashboard_clients).and_raise
        end

        it 'raises the error and does not create a new service broker' do
          expect {
            registration.save rescue nil
          }.to_not change(ServiceBroker, :count)
        end
      end
    end
  end
end
