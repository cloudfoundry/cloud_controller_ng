require 'spec_helper'

describe 'Synchronous orphan mitigation' do
  let(:logger) { double }
  let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }
  subject { VCAP::CloudController::SynchronousOrphanMitigate.new(logger) }

  before do
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe 'for service instances' do
    let(:service_instance) { instance_double(VCAP::CloudController::ManagedServiceInstance) }
    let(:service_instance_guid) { '5' }

    before do
      allow(service_instance).to receive(:client).and_return(client)
      allow(service_instance).to receive(:guid).and_return(service_instance_guid)
      allow(client).to receive(:deprovision)
    end

    it 'attempts to deprovision the service instance' do
      subject.attempt_deprovision_instance(service_instance)

      expect(client).to have_received(:deprovision).with(service_instance)
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_deprovision_instance(service_instance)

      expect(logger).to have_received(:info).with /Attempting.*#{service_instance_guid}/
    end

    it 'logs when successful' do
      subject.attempt_deprovision_instance(service_instance)

      expect(logger).to have_received(:info).with /Success.*#{service_instance_guid}/
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:deprovision).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_deprovision_instance(service_instance)

        expect(logger).to have_received(:error).with /Unable.*#{service_instance_guid}/
      end
    end
  end

  describe 'for unbinding' do
    let(:service_binding) { instance_double(VCAP::CloudController::ServiceBinding) }
    let(:service_binding_guid) { '5' }

    before do
      allow(service_binding).to receive(:client).and_return(client)
      allow(service_binding).to receive(:guid).and_return(service_binding_guid)
      allow(client).to receive(:unbind)
    end

    it 'attempts to unbind the binding' do
      subject.attempt_unbind(service_binding)

      expect(client).to have_received(:unbind).with(service_binding)
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_unbind(service_binding)

      expect(logger).to have_received(:info).with /Attempting.*#{service_binding_guid}/
    end

    it 'logs when successful' do
      subject.attempt_unbind(service_binding)

      expect(logger).to have_received(:info).with /Success.*#{service_binding_guid}/
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:unbind).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_unbind(service_binding)

        expect(logger).to have_received(:error).with /Unable.*#{service_binding_guid}/
      end
    end
  end

  describe 'for deleting service keys' do
    let(:service_key) { instance_double(VCAP::CloudController::ServiceKey) }
    let(:service_key_guid) { '5' }

    before do
      allow(service_key).to receive(:client).and_return(client)
      allow(service_key).to receive(:guid).and_return(service_key_guid)
      allow(client).to receive(:unbind)
    end

    it 'attempts to unbind the service key' do
      subject.attempt_delete_key(service_key)

      expect(client).to have_received(:unbind).with(service_key)
    end

    it 'logs that it is attempting to orphan mitigate' do
      subject.attempt_delete_key(service_key)

      expect(logger).to have_received(:info).with /Attempting.*#{service_key_guid}/
    end

    it 'logs when successful' do
      subject.attempt_delete_key(service_key)

      expect(logger).to have_received(:info).with /Success.*#{service_key_guid}/
    end

    context 'when the orphan mitigation fails' do
      before do
        allow(client).to receive(:unbind).and_raise
      end

      it 'logs that it failed' do
        subject.attempt_delete_key(service_key)

        expect(logger).to have_received(:error).with /Unable.*#{service_key_guid}/
      end
    end
  end
end
