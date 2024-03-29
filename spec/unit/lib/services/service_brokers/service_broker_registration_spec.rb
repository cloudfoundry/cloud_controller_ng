require 'spec_helper'

module VCAP::Services::ServiceBrokers
  RSpec.describe ServiceBrokerRegistration do
    subject(:registration) { ServiceBrokerRegistration.new(broker, service_manager, services_event_repository, false, false) }

    let(:client_manager) { instance_double(VCAP::Services::SSO::DashboardClientManager, synchronize_clients_with_catalog: true, warnings: []) }
    let(:catalog) { instance_double(VCAP::Services::ServiceBrokers::V2::Catalog, valid?: true) }
    let(:service_manager) { instance_double(VCAP::Services::ServiceBrokers::ServiceManager, sync_services_and_plans: true, has_warnings?: false) }
    let(:services_event_repository) { instance_double(VCAP::CloudController::Repositories::ServiceEventRepository) }
    let(:basic_auth) { %w[cc auth1234] }

    describe 'initializing' do
      let(:broker) { VCAP::CloudController::ServiceBroker.make }

      its(:broker) { is_expected.to eq(broker) }
      its(:warnings) { is_expected.to eq([]) }
      its(:errors) { is_expected.to eq(broker.errors) }
    end

    describe '#create' do
      let(:broker) do
        VCAP::CloudController::ServiceBroker.new(
          name: 'Cool Broker',
          broker_url: 'http://broker.example.com',
          auth_username: 'cc',
          auth_password: 'auth1234'
        )
      end

      before do
        stub_request(:get, 'http://broker.example.com/v2/catalog').with(basic_auth:).to_return(body: '{}')
        allow(VCAP::Services::SSO::DashboardClientManager).to receive(:new).and_return(client_manager)
        allow(V2::Catalog).to receive(:new).and_return(catalog)
        allow(catalog).to receive(:services).and_return([])
        allow(ServiceManager).to receive(:new).and_return(service_manager)

        allow(client_manager).to receive(:has_warnings?).and_return(false)
      end

      it 'returns itself' do
        expect(registration.create).to eq(registration)
      end

      it 'creates a service broker' do
        expect do
          registration.create
        end.to change(VCAP::CloudController::ServiceBroker, :count).from(0).to(1)

        expect(broker).to eq(VCAP::CloudController::ServiceBroker.last)

        expect(broker.name).to eq('Cool Broker')
        expect(broker.broker_url).to eq('http://broker.example.com')
        expect(broker.auth_username).to eq('cc')
        expect(broker.auth_password).to eq('auth1234')
        expect(broker).to be_exists
      end

      it 'fetches the catalog' do
        registration.create

        expect(a_request(:get, 'http://broker.example.com/v2/catalog').with(basic_auth:)).to have_been_requested
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

        expect(VCAP::Services::SSO::DashboardClientManager).to have_received(:new).with(
          broker,
          services_event_repository
        )
        expect(client_manager).to have_received(:synchronize_clients_with_catalog).with(catalog)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          let(:broker) { VCAP::CloudController::ServiceBroker.new }

          it 'returns nil' do
            expect(registration.create).to be_nil
          end

          it 'does not create a new service broker' do
            expect do
              registration.create
            end.not_to change(VCAP::CloudController::ServiceBroker, :count)
          end

          it 'does not fetch the catalog' do
            registration.create

            expect(a_request(:get, /.*/)).not_to have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.create

            expect(registration.errors.on(:name)).to include(:presence)
          end

          it 'does not synchronize uaa clients' do
            registration.create

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            registration.create

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { instance_double(VCAP::Services::ServiceBrokers::ValidationErrorsFormatter, format: 'something bad happened') }

          before do
            allow(catalog).to receive_messages(valid?: false, errors: errors)
            allow(ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue CloudController::Errors::ApiError
            end

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue CloudController::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end

          it 'raises a ServiceBrokerCatalogInvalid error with a human-readable message' do
            expect { registration.create }.to raise_error(CloudController::Errors::ApiError, /something bad happened/)
            expect(formatter).to have_received(:format).with(errors)
          end
        end

        context 'because the catalog fetch failed' do
          before do
            stub_request(:get, 'http://broker.example.com/v2/catalog').with(basic_auth:).to_return(status: 500)
          end

          it "raises an error, even though we'd rather it not" do
            expect do
              registration.create
            end.to raise_error V2::Errors::ServiceBrokerBadResponse
          end

          it 'does not create a new service broker' do
            expect do
              registration.create
            rescue StandardError
              nil
            end.not_to change(VCAP::CloudController::ServiceBroker, :count)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.create
            rescue V2::Errors::ServiceBrokerBadResponse
            end

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue V2::Errors::ServiceBrokerBadResponse
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the dashboard client manager failed' do
          before do
            allow(client_manager).to receive_messages(synchronize_clients_with_catalog: false, errors: validation_errors)
            allow_any_instance_of(ValidationErrorsFormatter).to receive(:format).and_return(error_text)
          end

          let(:error_text) { 'something bad happened' }
          let(:validation_errors) { instance_double(VCAP::Services::ValidationErrors) }

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.create }.to raise_error(CloudController::Errors::ApiError, /#{error_text}/)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.create
            rescue CloudController::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          allow(catalog).to receive(:valid?).and_return(true)
          allow(client_manager).to receive(:synchronize_clients_with_catalog) {
            VCAP::CloudController::ServiceDashboardClient.make(uaa_id: 'my-uaa-id', service_broker_id: broker.id)
          }
          allow(service_manager).to receive(:sync_services_and_plans).and_raise(CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', 'omg it broke'))
        end

        it 'does not save new broker' do
          expect(VCAP::CloudController::ServiceBroker.count).to eq(0)
          expect do
            registration.create
          rescue CloudController::Errors::ApiError
          end.not_to(change(VCAP::CloudController::ServiceBroker, :count))
        end

        it 'nullifies the service_broker_id field of the created dashboard clients' do
          expect(VCAP::CloudController::ServiceDashboardClient.count).to eq(0)
          expect do
            registration.create
          rescue CloudController::Errors::ApiError
          end.to change(VCAP::CloudController::ServiceDashboardClient, :count).by(1)

          expect(VCAP::CloudController::ServiceDashboardClient.last.service_broker_id).to be_nil
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          allow(catalog).to receive(:valid?).and_return(true)
          allow(client_manager).to receive(:synchronize_clients_with_catalog).and_raise
        end

        it 'raises the error and does not create a new service broker' do
          expect do
            registration.create
          rescue StandardError
            nil
          end.not_to change(VCAP::CloudController::ServiceBroker, :count)
        end

        it 'does not synchronize the catalog' do
          begin
            registration.create
          rescue StandardError
            nil
          end

          expect(service_manager).not_to have_received(:sync_services_and_plans)
        end
      end

      context 'when the client manager has warnings' do
        before do
          allow(client_manager).to receive_messages(warnings: %w[warning1 warning2], has_warnings?: true)
        end

        it 'adds the warnings' do
          registration.create

          expect(registration.warnings).to eq(%w[warning1 warning2])
        end
      end

      context 'when the service manager has warnings' do
        before do
          allow(service_manager).to receive_messages(warnings: %w[warning1 warning2], has_warnings?: true)
        end

        it 'adds the warnings' do
          registration.create

          expect(registration.warnings).to eq(%w[warning1 warning2])
        end
      end

      context 'when volume_services_enabled is false and a service requires volume_mount' do
        let(:volume_mount_plan) { instance_double(V2::CatalogService, route_service?: false, volume_mount_service?: true, name: 'service-name') }

        before do
          allow(catalog).to receive(:services).and_return([volume_mount_plan])
        end

        it 'adds a warning' do
          registration.create

          expected_warning = 'Service service-name is declared to be a volume mount service but support for volume mount services is disabled. ' \
                             'Users will be prevented from binding instances of this service with apps.'

          expect(registration.warnings).to include(expected_warning)
        end
      end
    end

    describe '#update' do
      let(:old_broker_host) { 'broker.example.com' }
      let!(:broker) do
        VCAP::CloudController::ServiceBroker.make(
          name: 'Cool Broker',
          broker_url: "http://#{old_broker_host}",
          auth_username: 'cc',
          auth_password: 'auth1234'
        )
      end

      let(:new_broker_host) { 'new-broker.com' }
      let(:new_name) { 'new-name' }
      let(:status) { 200 }
      let(:body) { '{}' }

      before do
        stub_request(:get, "http://#{new_broker_host}/v2/catalog").with(basic_auth:).to_return(status:, body:)
        allow(VCAP::Services::SSO::DashboardClientManager).to receive(:new).and_return(client_manager)
        allow(V2::Catalog).to receive(:new).and_return(catalog)
        allow(catalog).to receive(:services).and_return([])
        allow(ServiceManager).to receive(:new).and_return(service_manager)

        allow(client_manager).to receive(:has_warnings?).and_return(false)

        broker.name = new_name
        broker.broker_url = "http://#{new_broker_host}"
      end

      it 'returns itself' do
        expect(registration.update).to eq(registration)
      end

      it 'does not create a new service broker' do
        expect do
          registration.update
        end.not_to change(VCAP::CloudController::ServiceBroker, :count)
      end

      it 'updates a service broker' do
        broker.name = 'something-else'
        registration.update

        broker.reload
        expect(broker.name).to eq('something-else')
      end

      context 'when only the name is updated' do
        before do
          broker.broker_url = "http://#{old_broker_host}"
          broker.name = new_name
        end

        it 'does not fetch the catalog' do
          registration.update

          expect(broker.name).to eq new_name
          expect(a_request(:get, "http://#{old_broker_host}/v2/catalog").with(basic_auth:)).not_to have_been_requested
          expect(a_request(:get, "http://#{new_broker_host}/v2/catalog").with(basic_auth:)).not_to have_been_requested
        end
      end

      context 'when the name and another field is updated' do
        before do
          stub_request(:get, 'http://something-url.com/v2/catalog').with(basic_auth:).to_return(body: '{}')
        end

        it 'fetches the catalog' do
          broker.name = 'something-else'
          broker.broker_url = 'http://something-url.com'
          registration.update

          expect(a_request(:get, 'http://something-url.com/v2/catalog').with(basic_auth:)).to have_been_requested
        end
      end

      it 'fetches the catalog' do
        registration.update

        expect(a_request(:get, "http://#{new_broker_host}/v2/catalog").with(basic_auth:)).to have_been_requested
      end

      it 'syncs services and plans' do
        registration.update

        expect(service_manager).to have_received(:sync_services_and_plans)
      end

      it 'updates dashboard clients' do
        registration.update

        expect(VCAP::Services::SSO::DashboardClientManager).to have_received(:new).with(
          broker,
          services_event_repository
        )
        expect(client_manager).to have_received(:synchronize_clients_with_catalog).with(catalog)
      end

      context 'when invalid' do
        context 'because the broker has errors' do
          before do
            broker.name = nil
          end

          it 'returns nil' do
            expect(registration.update).to be_nil
          end

          it 'does not update the service broker' do
            expect do
              registration.update
            end.not_to(change { VCAP::CloudController::ServiceBroker[broker.id].name })
          end

          it 'does not fetch the catalog' do
            registration.update

            expect(a_request(:get, /.*/)).not_to have_been_requested
          end

          it 'adds the broker errors to the registration errors' do
            registration.update

            expect(registration.errors.on(:name)).to include(:presence)
          end

          it 'does not synchronize uaa clients' do
            registration.update

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            registration.update

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the catalog has errors' do
          let(:errors) { double(:errors) }
          let(:formatter) { instance_double(VCAP::Services::ServiceBrokers::ValidationErrorsFormatter, format: 'something bad happened') }

          before do
            allow(catalog).to receive_messages(valid?: false, errors: errors)
            allow(ValidationErrorsFormatter).to receive(:new).and_return(formatter)
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue CloudController::Errors::ApiError
            end

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue CloudController::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end

          it 'raises a ServiceBrokerCatalogInvalid error with a human-readable message' do
            expect { registration.update }.to raise_error(CloudController::Errors::ApiError, /something bad happened/)
            expect(formatter).to have_received(:format).with(errors)
          end
        end

        context 'because the catalog fetch failed' do
          let(:status) { 500 }
          let(:body) { '{"description":"error message"}' }

          it "raises an error, even though we'd rather it not" do
            expect do
              registration.update
            end.to raise_error V2::Errors::ServiceBrokerBadResponse
          end

          it 'not update the service broker' do
            expect do
              registration.update
            rescue StandardError
              nil
            end.not_to(change { VCAP::CloudController::ServiceBroker[broker.id].name })
          end

          it 'does not synchronize uaa clients' do
            begin
              registration.update
            rescue V2::Errors::ServiceBrokerBadResponse
            end

            expect(client_manager).not_to have_received(:synchronize_clients_with_catalog)
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue V2::Errors::ServiceBrokerBadResponse
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end

        context 'because the dashboard client manager failed' do
          before do
            allow(client_manager).to receive_messages(synchronize_clients_with_catalog: false, errors: validation_errors)
            allow_any_instance_of(ValidationErrorsFormatter).to receive(:format).and_return(error_text)
          end

          let(:error_text) { 'something bad happened' }
          let(:validation_errors) { instance_double(VCAP::Services::ValidationErrors) }

          it 'raises a ServiceBrokerCatalogInvalid error' do
            expect { registration.update }.to raise_error(CloudController::Errors::ApiError, /#{error_text}/)
          end

          it 'not update the service broker' do
            expect do
              registration.update
            rescue StandardError
              nil
            end.not_to(change { VCAP::CloudController::ServiceBroker[broker.id].name })
          end

          it 'does not synchronize the catalog' do
            begin
              registration.update
            rescue CloudController::Errors::ApiError
            end

            expect(service_manager).not_to have_received(:sync_services_and_plans)
          end
        end
      end

      context 'when exception is raised during transaction' do
        before do
          allow(catalog).to receive(:valid?).and_return(true)
          allow(service_manager).to receive(:sync_services_and_plans).and_raise(CloudController::Errors::ApiError.new_from_details('ServiceBrokerCatalogInvalid', 'omg it broke'))
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect do
            registration.update
          rescue CloudController::Errors::ApiError
          end.not_to(change { VCAP::CloudController::ServiceBroker[broker.id].name })
        end
      end

      context 'when exception is raised during dashboard client creation' do
        before do
          allow(catalog).to receive(:valid?).and_return(true)
          allow(client_manager).to receive(:synchronize_clients_with_catalog).and_raise
        end

        it 'raises the error' do
          expect { registration.update }.to raise_error(RuntimeError)
        end

        it 'does not update the broker' do
          broker.name = 'something-else'
          expect do
            registration.update
          rescue StandardError
            nil
          end.not_to(change { VCAP::CloudController::ServiceBroker[broker.id].name })
        end

        it 'does not synchronize the catalog' do
          begin
            registration.update
          rescue StandardError
            nil
          end

          expect(service_manager).not_to have_received(:sync_services_and_plans)
        end
      end

      context 'when the client manager has warnings' do
        before do
          allow(client_manager).to receive_messages(warnings: %w[warning1 warning2], has_warnings?: true)
        end

        it 'adds the warnings' do
          registration.update

          expect(registration.warnings).to eq(%w[warning1 warning2])
        end
      end

      context 'when the service manager has warnings' do
        before do
          allow(service_manager).to receive_messages(warnings: %w[warning1 warning2], has_warnings?: true)
        end

        it 'adds the warnings' do
          registration.update

          expect(registration.warnings).to eq(%w[warning1 warning2])
        end
      end

      context 'when volume_services_enabled is false and a service requires volume_mount' do
        let(:volume_mount_plan) { instance_double(V2::CatalogService, route_service?: false, volume_mount_service?: true, name: 'service-name') }

        before do
          allow(catalog).to receive(:services).and_return([volume_mount_plan])
        end

        it 'adds a warning' do
          registration.update

          expected_warning = 'Service service-name is declared to be a volume mount service but support for volume mount services is disabled. ' \
                             'Users will be prevented from binding instances of this service with apps.'

          expect(registration.warnings).to include(expected_warning)
        end
      end
    end
  end
end
