require 'spec_helper'
require 'models/services/service_broker_registration'

module VCAP::CloudController
  describe ServiceBrokerRegistration do
    describe '#create' do
      let(:broker) do
        ServiceBroker.new(
          name:          'Cool Broker',
          broker_url:    'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
        )
      end
      let(:manager) { double(:service_dashboard_manager, :synchronize_clients => true) }
      let(:catalog) { double(:catalog, :sync_services_and_plans => true, :valid? => true) }

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
        allow(ServiceBrokers::V2::ServiceDashboardClientManager).to receive(:new).and_return(manager)
        allow(ServiceBrokers::V2::Catalog).to receive(:new).and_return(catalog)
      end

      it 'returns itself' do
        expect(registration.create).to eq(registration)
      end

      it 'creates a service broker' do
        expect {
          registration.create
        }.to change(ServiceBroker, :count).from(0).to(1)

        expect(broker).to eq(ServiceBroker.last)

        expect(broker.name).to eq('Cool Broker')
        expect(broker.broker_url).to eq('http://broker.example.com')
        expect(broker.auth_username).to eq('cc')
        expect(broker.auth_password).to eq('auth1234')
        expect(broker).to be_exists
      end

      it 'fetches the catalog' do
        registration.create

        expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to have_been_requested
      end

      it 'resets errors before saving' do
        registration.broker.name = ''
        expect(registration.create).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
        expect(registration.create).to be_nil
        expect(registration.errors.on(:name)).to have_exactly(1).error
      end

      it 'syncs services and plans' do
        registration.create

        expect(catalog).to have_received(:sync_services_and_plans)
      end

      it 'creates dashboard clients' do
        registration.create

        expect(ServiceBrokers::V2::ServiceDashboardClientManager).to have_received(:new).with(catalog, broker)
        expect(manager).to have_received(:synchronize_clients)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:broker) { ServiceBroker.new }
          let(:registration) { ServiceBrokerRegistration.new(broker) }

          it 'returns nil' do
            expect(registration.create).to be_nil
          end

          it 'does not create a new service broker' do
            expect {
              registration.create
            }.to_not change(ServiceBroker, :count)
          end

          it 'does not fetch the catalog' do
            registration.create

            expect(a_request(:get, /.*/)).to_not have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.create

            expect(registration.errors.on(:name)).to include(:presence)
          end

          it 'does not synchronize uaa clients' do
            registration.create

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            registration.create

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { double(:formatter, format: 'something bad happened') }
          before do
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:errors).and_return(errors)
            allow(ServiceBrokers::V2::ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end

          it 'raises a ServiceBrokerCatalogInvalid error with a human-readable message' do
            expect { registration.create }.to raise_error(VCAP::Errors::ApiError, /something bad happened/)
            expect(formatter).to have_received(:format).with(errors)
          end
        end

        context 'because the catalog fetch failed' do
          before do
            stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(status: 500)
          end

          it "raises an error, even though we'd rather it not" do
            expect {
              registration.create
            }.to raise_error ServiceBrokers::V2::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect {
              registration.create rescue nil
            }.to_not change(ServiceBroker, :count)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue ServiceBrokers::V2::ServiceBrokerBadResponse
            end

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue ServiceBrokers::V2::ServiceBrokerBadResponse
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end

        end

        context 'because the dashboard client manager failed' do
          before do
            allow(manager).to receive(:synchronize_clients).and_return(false)
            allow(manager).to receive(:errors).and_return(validation_errors)
            allow_any_instance_of(ServiceBrokers::V2::ValidationErrorsFormatter).to receive(:format).and_return(error_text)
          end

          let(:error_text) { 'something bad happened' }
          let(:validation_errors) { double(:validation_errors) }

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.create }.to raise_error(VCAP::Errors::ApiError, /#{error_text}/)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          catalog.stub(:valid?).and_return(true)
          catalog.stub(:sync_services_and_plans).and_raise(Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", 'omg it broke'))
        end

        it 'does not save new broker' do
          expect(ServiceBroker.count).to eq(0)
          expect {
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end
          }.to change { ServiceBroker.count }.by(0)
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          catalog.stub(:valid?).and_return(true)
          manager.stub(:synchronize_clients).and_raise
        end

        it 'raises the error and does not create a new service broker' do
          expect {
            registration.create rescue nil
          }.to_not change(ServiceBroker, :count)
        end


        it 'does not synchronize the catalog' do
          registration.create rescue nil

          expect(catalog).not_to have_received(:sync_services_and_plans)
        end
      end
    end
    
    describe '#update' do
      let!(:broker) do
        ServiceBroker.make(
          name:          'Cool Broker',
          broker_url:    'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
        )
      end
      let(:manager) { double(:service_dashboard_manager, :synchronize_clients => true) }
      let(:catalog) { double(:catalog, :sync_services_and_plans => true, :valid? => true) }

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
        allow(ServiceBrokers::V2::ServiceDashboardClientManager).to receive(:new).and_return(manager)
        allow(ServiceBrokers::V2::Catalog).to receive(:new).and_return(catalog)
      end

      it 'returns itself' do
        expect(registration.update).to eq(registration)
      end

      it 'does not create a new service broker' do
        expect {
          registration.update
        }.not_to change(ServiceBroker, :count)

      end

      it 'updates a service broker' do
        broker.name = 'something-else'
        registration.update

        broker.reload
        expect(broker.name).to eq('something-else')
      end

      it 'fetches the catalog' do
        registration.update

        expect(a_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog')).to have_been_requested
      end

      it 'syncs services and plans' do
        registration.update

        expect(catalog).to have_received(:sync_services_and_plans)
      end

      it 'updates dashboard clients' do
        registration.update

        expect(ServiceBrokers::V2::ServiceDashboardClientManager).to have_received(:new).with(catalog, broker)
        expect(manager).to have_received(:synchronize_clients)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:registration) { ServiceBrokerRegistration.new(broker) }

          before do
            broker.name = nil
          end

          it 'returns nil' do
            expect(registration.update).to be_nil
          end

          it 'does not update the service broker' do
            expect {
              registration.update
            }.to_not change { ServiceBroker[broker.id].name }
          end

          it 'does not fetch the catalog' do
            registration.update

            expect(a_request(:get, /.*/)).to_not have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.update

            expect(registration.errors.on(:name)).to include(:presence)
          end

          it 'does not synchronize uaa clients' do
            registration.update

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            registration.update

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { double(:formatter, format: 'something bad happened') }
          before do
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:errors).and_return(errors)
            allow(ServiceBrokers::V2::ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end

          it 'raises a ServiceBrokerCatalogInvalid error with a human-readable message' do
            expect { registration.update }.to raise_error(VCAP::Errors::ApiError, /something bad happened/)
            expect(formatter).to have_received(:format).with(errors)
          end
        end

        context 'because the catalog fetch failed' do
          before do
            stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(status: 500)
          end

          it "raises an error, even though we'd rather it not" do
            expect {
              registration.update
            }.to raise_error ServiceBrokers::V2::ServiceBrokerBadResponse
          end

          it 'not update the service broker' do
            broker.name = 'something-else'
            expect {
              registration.update rescue nil
            }.to_not change { ServiceBroker[broker.id].name }
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue ServiceBrokers::V2::ServiceBrokerBadResponse
            end

            expect(manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue ServiceBrokers::V2::ServiceBrokerBadResponse
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end

        end

        context 'because the dashboard client manager failed' do
          before do
            allow(manager).to receive(:synchronize_clients).and_return(false)
            allow(manager).to receive(:errors).and_return(validation_errors)
            allow_any_instance_of(ServiceBrokers::V2::ValidationErrorsFormatter).to receive(:format).and_return(error_text)
          end

          let(:error_text) { 'something bad happened' }
          let(:validation_errors) { double(:validation_errors) }

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.update }.to raise_error(VCAP::Errors::ApiError, /#{error_text}/)
          end

          it 'not update the service broker' do
            broker.name = 'something-else'
            expect {
              registration.update rescue nil
            }.to_not change { ServiceBroker[broker.id].name }
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(catalog).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          catalog.stub(:valid?).and_return(true)
          catalog.stub(:sync_services_and_plans).and_raise(Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", 'omg it broke'))
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect {
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end
          }.not_to change { ServiceBroker[broker.id].name }
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          catalog.stub(:valid?).and_return(true)
          manager.stub(:synchronize_clients).and_raise
        end

        it 'raises the error' do
          expect { registration.update }.to raise_error
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect {
            registration.update rescue nil
          }.not_to change { ServiceBroker[broker.id].name }
        end

        it 'does not synchronize the catalog' do
          registration.update rescue nil

          expect(catalog).not_to have_received(:sync_services_and_plans)
        end
      end
    end
  end
end
