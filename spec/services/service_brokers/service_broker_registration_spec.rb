require 'spec_helper'

module VCAP::Services::ServiceBrokers
  describe ServiceBrokerRegistration do
    describe '#create' do
      let(:broker) do
        VCAP::CloudController::ServiceBroker.new(
          name:          'Cool Broker',
          broker_url:    'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
        )
      end
      let(:client_manager) { double(:service_dashboard_manager, :synchronize_clients => true) }
      let(:catalog) { double(:catalog, :valid? => true) }
      let(:service_manager) { double(:service_manager, :sync_services_and_plans => true) }

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
        allow(ServiceDashboardClientManager).to receive(:new).and_return(client_manager)
        allow(V2::Catalog).to receive(:new).and_return(catalog)
        allow(ServiceManager).to receive(:new).and_return(service_manager)
      end

      it 'returns itself' do
        expect(registration.create).to eq(registration)
      end

      it 'creates a service broker' do
        expect {
          registration.create
        }.to change(VCAP::CloudController::ServiceBroker, :count).from(0).to(1)

        expect(broker).to eq(VCAP::CloudController::ServiceBroker.last)

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

        expect(service_manager).to have_received(:sync_services_and_plans)
      end

      it 'creates dashboard clients' do
        registration.create

        expect(ServiceDashboardClientManager).to have_received(:new).with(catalog, broker)
        expect(client_manager).to have_received(:synchronize_clients)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:broker) { VCAP::CloudController::ServiceBroker.new }
          let(:registration) { ServiceBrokerRegistration.new(broker) }

          it 'returns nil' do
            expect(registration.create).to be_nil
          end

          it 'does not create a new service broker' do
            expect {
              registration.create
            }.to_not change(VCAP::CloudController::ServiceBroker, :count)
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

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            registration.create

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { double(:formatter, format: 'something bad happened') }
          before do
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:errors).and_return(errors)
            allow(ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
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
            }.to raise_error V2::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect {
              registration.create rescue nil
            }.to_not change(VCAP::CloudController::ServiceBroker, :count)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue V2::ServiceBrokerBadResponse
            end

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue V2::ServiceBrokerBadResponse
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end

        end

        context 'because the dashboard client manager failed' do
          before do
            allow(client_manager).to receive(:synchronize_clients).and_return(false)
            allow(client_manager).to receive(:errors).and_return(validation_errors)
            allow_any_instance_of(ValidationErrorsFormatter).to receive(:format).and_return(error_text)
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

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          catalog.stub(:valid?).and_return(true)
          client_manager.stub(:synchronize_clients) {
            VCAP::CloudController::ServiceDashboardClient.make(uaa_id: 'my-uaa-id', service_broker_id: broker.id)
          }
          service_manager.stub(:sync_services_and_plans).and_raise(VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", 'omg it broke'))
        end

        it 'does not save new broker' do
          expect(VCAP::CloudController::ServiceBroker.count).to eq(0)
          expect {
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end
          }.to change { VCAP::CloudController::ServiceBroker.count }.by(0)
        end

        it 'nullifies the service_broker_id field of the created dashboard clients' do
          expect(VCAP::CloudController::ServiceDashboardClient.count).to eq(0)
          expect {
            begin
              registration.create
            rescue VCAP::Errors::ApiError
            end
          }.to change { VCAP::CloudController::ServiceDashboardClient.count }.by(1)

          expect(VCAP::CloudController::ServiceDashboardClient.last.service_broker_id).to be_nil
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          catalog.stub(:valid?).and_return(true)
          client_manager.stub(:synchronize_clients).and_raise
        end

        it 'raises the error and does not create a new service broker' do
          expect {
            registration.create rescue nil
          }.to_not change(VCAP::CloudController::ServiceBroker, :count)
        end


        it 'does not synchronize the catalog' do
          registration.create rescue nil

          expect(service_manager).not_to have_received(:sync_services_and_plans)
        end
      end
    end
    
    describe '#update' do
      let!(:broker) do
        VCAP::CloudController::ServiceBroker.make(
          name:          'Cool Broker',
          broker_url:    'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234',
        )
      end
      let(:client_manager) { double(:service_dashboard_manager, :synchronize_clients => true) }
      let(:catalog) { double(:catalog, :valid? => true) }
      let(:service_manager) { double(:service_manager, :sync_services_and_plans => true) }

      subject(:registration) { ServiceBrokerRegistration.new(broker) }

      before do
        stub_request(:get, 'http://cc:auth1234@broker.example.com/v2/catalog').to_return(body: '{}')
        allow(ServiceDashboardClientManager).to receive(:new).and_return(client_manager)
        allow(V2::Catalog).to receive(:new).and_return(catalog)
        allow(ServiceManager).to receive(:new).and_return(service_manager)
      end

      it 'returns itself' do
        expect(registration.update).to eq(registration)
      end

      it 'does not create a new service broker' do
        expect {
          registration.update
        }.not_to change(VCAP::CloudController::ServiceBroker, :count)

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

        expect(service_manager).to have_received(:sync_services_and_plans)
      end

      it 'updates dashboard clients' do
        registration.update

        expect(ServiceDashboardClientManager).to have_received(:new).with(catalog, broker)
        expect(client_manager).to have_received(:synchronize_clients)
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
            }.to_not change { VCAP::CloudController::ServiceBroker[broker.id].name }
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

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            registration.update

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { double(:formatter, format: 'something bad happened') }
          before do
            catalog.stub(:valid?).and_return(false)
            catalog.stub(:errors).and_return(errors)
            allow(ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
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
            }.to raise_error V2::ServiceBrokerBadResponse
          end

          it 'not update the service broker' do
            broker.name = 'something-else'
            expect {
              registration.update rescue nil
            }.to_not change { VCAP::CloudController::ServiceBroker[broker.id].name }
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue V2::ServiceBrokerBadResponse
            end

            expect(client_manager).not_to have_received(:synchronize_clients)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue V2::ServiceBrokerBadResponse
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end

        end

        context 'because the dashboard client manager failed' do
          before do
            allow(client_manager).to receive(:synchronize_clients).and_return(false)
            allow(client_manager).to receive(:errors).and_return(validation_errors)
            allow_any_instance_of(ValidationErrorsFormatter).to receive(:format).and_return(error_text)
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
            }.to_not change { VCAP::CloudController::ServiceBroker[broker.id].name }
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          catalog.stub(:valid?).and_return(true)
          service_manager.stub(:sync_services_and_plans).and_raise(VCAP::Errors::ApiError.new_from_details("ServiceBrokerCatalogInvalid", 'omg it broke'))
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect {
            begin
              registration.update
            rescue VCAP::Errors::ApiError
            end
          }.not_to change { VCAP::CloudController::ServiceBroker[broker.id].name }
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          catalog.stub(:valid?).and_return(true)
          client_manager.stub(:synchronize_clients).and_raise
        end

        it 'raises the error' do
          expect { registration.update }.to raise_error
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect {
            registration.update rescue nil
          }.not_to change { VCAP::CloudController::ServiceBroker[broker.id].name }
        end

        it 'does not synchronize the catalog' do
          registration.update rescue nil

          expect(service_manager).not_to have_received(:sync_services_and_plans)
        end
      end
    end
  end
end
