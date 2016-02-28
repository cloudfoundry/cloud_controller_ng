require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::UserProvidedServiceInstance, type: :model do
    let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

    it_behaves_like 'a model with an encrypted attribute' do
      def new_model
        described_class.create(
          name: Sham.name,
          space: VCAP::CloudController::Space.make,
          credentials: value_to_encrypt,
        )
      end

      let(:encrypted_attr) { :credentials }
      let(:attr_salt) { :salt }
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :space }
      it do
        is_expected.to have_associated :service_bindings, associated_instance: ->(service_instance) {
          app = VCAP::CloudController::App.make(space: service_instance.space)
          ServiceBinding.make(app: app, service_instance: service_instance, credentials: Sham.service_credentials)
        }
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :space }
      it { is_expected.to strip_whitespace :name }
      it { is_expected.to strip_whitespace :syslog_drain_url }

      it 'should not bind an app and a service instance from different app spaces' do
        service_instance = described_class.make
        VCAP::CloudController::AppFactory.make(space: service_instance.space)
        service_binding = VCAP::CloudController::ServiceBinding.make
        expect {
          service_instance.add_service_binding(service_binding)
        }.to raise_error VCAP::CloudController::ServiceInstance::InvalidServiceBinding
      end

      it 'raises an error if the route_service_url is not https' do
        expect {
          described_class.make(route_service_url: 'http://route.url.com')
        }.
          to raise_error(Sequel::ValidationFailed, 'service_instance route_service_url_not_https')
      end

      it 'raises an error if the route_service_url does not have a valid host' do
        expect {
          described_class.make(route_service_url: 'https://.com')
        }.
          to raise_error(Sequel::ValidationFailed, 'service_instance route_service_url_invalid')
      end

      it 'raises an error if the route_service_url format is invalid' do
        expect {
          described_class.make(route_service_url: 'https\\route')
        }.
          to raise_error(Sequel::ValidationFailed, 'service_instance route_service_url_invalid')
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url, :route_service_url }
      it { is_expected.to import_attributes :name, :credentials, :space_guid, :syslog_drain_url, :route_service_url }
    end

    describe '#create' do
      it 'saves with is_gateway_service false' do
        instance = described_class.create(
          name: 'awesome-service',
          space: VCAP::CloudController::Space.make,
          credentials: { 'foo' => 'bar' },
          route_service_url: 'https://route.url.com'
        )
        expect(instance.refresh.is_gateway_service).to be false
      end

      it 'creates a CREATED service usage event' do
        instance = described_class.make

        event = ServiceUsageEvent.last
        expect(ServiceUsageEvent.count).to eq(1)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::CREATED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end

      it 'should create the service instance if the route_service_url is empty' do
        described_class.make(route_service_url: '')
        expect(ServiceInstance.count).to eq(1)
      end
    end

    describe '#delete' do
      it 'creates a DELETED service usage event' do
        instance = described_class.make
        instance.destroy

        event = VCAP::CloudController::ServiceUsageEvent.last

        expect(VCAP::CloudController::ServiceUsageEvent.count).to eq(2)
        expect(event.state).to eq(Repositories::Services::ServiceUsageEventRepository::DELETED_EVENT_STATE)
        expect(event).to match_service_instance(instance)
      end
    end

    describe '#tags' do
      it 'does not have tags' do
        service_instance = described_class.make
        expect(service_instance.tags).to eq []
      end
    end

    it 'pretends it can #save_with_new_operation' do
      service_instance.save_with_new_operation({ foo: 'bar' }, { baz: 'bot' })
    end
  end
end
