require 'spec_helper'

RSpec.describe 'DatabaseErrorServiceResourceCleanup' do
  subject { VCAP::CloudController::DatabaseErrorServiceResourceCleanup.new(logger) }

  let(:logger) { double }
  let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe 'for service instances' do
    let(:service_instance) { instance_double(VCAP::CloudController::ManagedServiceInstance) }
    let(:service_instance_guid) { '5' }

    before do
      allow(service_instance).to receive(:guid).and_return(service_instance_guid)
      allow(client).to receive(:deprovision)

      allow(VCAP::Services::ServiceClientProvider).to receive(:provide).
        with(hash_including(instance: service_instance)).and_return(client)
    end

    it 'attempts to deprovision the service instance' do
      subject.attempt_deprovision_instance(service_instance)

      expect(client).to have_received(:deprovision).with(service_instance, accepts_incomplete: true)
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_deprovision_instance(service_instance)

      expect(logger).to have_received(:info).with(/Attempting.*service instance #{service_instance_guid}/)
    end

    it 'logs when successful' do
      subject.attempt_deprovision_instance(service_instance)

      expect(logger).to have_received(:info).with(/Success.*service instance #{service_instance_guid}/)
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:deprovision).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_deprovision_instance(service_instance)

        expect(logger).to have_received(:error).with(/Unable.*service instance #{service_instance_guid}/)
      end
    end
  end

  describe 'for unbinding' do
    let(:service_binding) { instance_double(VCAP::CloudController::ServiceBinding) }
    let(:service_instance) { instance_double(VCAP::CloudController::ServiceInstance) }
    let(:service_binding_guid) { '5' }

    before do
      allow(service_binding).to receive_messages(guid: service_binding_guid, service_instance: service_instance)
      allow(client).to receive(:unbind)

      allow(VCAP::Services::ServiceClientProvider).to receive(:provide).
        with(hash_including(instance: service_binding.service_instance)).and_return(client)
    end

    it 'attempts to unbind the binding' do
      subject.attempt_unbind(service_binding)

      expect(client).to have_received(:unbind).with(service_binding, { accepts_incomplete: true })
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_unbind(service_binding)

      expect(logger).to have_received(:info).with(/Attempting.*service binding #{service_binding_guid}/)
    end

    it 'logs when successful' do
      subject.attempt_unbind(service_binding)

      expect(logger).to have_received(:info).with(/Success.*service binding #{service_binding_guid}/)
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:unbind).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_unbind(service_binding)

        expect(logger).to have_received(:error).with(/Unable.*service binding #{service_binding_guid}/)
      end
    end
  end

  describe 'for deleting service keys' do
    let(:service_key) { instance_double(VCAP::CloudController::ServiceKey) }
    let(:service_instance) { instance_double(VCAP::CloudController::ServiceInstance) }
    let(:service_key_guid) { '5' }

    before do
      allow(service_key).to receive_messages(guid: service_key_guid, service_instance: service_instance)
      allow(client).to receive(:unbind)

      allow(VCAP::Services::ServiceClientProvider).to receive(:provide).
        with(hash_including(instance: service_key.service_instance)).and_return(client)
    end

    it 'attempts to unbind the service key' do
      subject.attempt_delete_key(service_key)

      expect(client).to have_received(:unbind).with(service_key)
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_delete_key(service_key)

      expect(logger).to have_received(:info).with(/Attempting.*service key #{service_key_guid}/)
    end

    it 'logs when successful' do
      subject.attempt_delete_key(service_key)

      expect(logger).to have_received(:info).with(/Success.*service key #{service_key_guid}/)
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:unbind).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_delete_key(service_key)

        expect(logger).to have_received(:error).with(/Unable.*service key #{service_key_guid}/)
      end
    end
  end
end
