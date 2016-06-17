require 'spec_helper'
require 'presenters/message_bus/service_binding_presenter'

RSpec.describe ServiceBindingPresenter do
  context 'for a managed service instance' do
    let(:service) { VCAP::CloudController::Service.make(requires: ['syslog_drain'], label: Sham.label) }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(name: Sham.name, service: service) }
    let(:service_instance) do
      VCAP::CloudController::ManagedServiceInstance.make(
        name: Sham.name,
        service_plan: service_plan
      )
    end
    let(:binding_options) { nil }
    let(:service_binding) do
      VCAP::CloudController::ServiceBinding.make(
        service_instance: service_instance,
        binding_options: binding_options
      )
    end

    context 'with syslog_drain_url' do
      before do
        service_binding.update(syslog_drain_url: 'syslog://example.com:514')
      end

      describe '#to_hash' do
        subject { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

        specify do
          expect(subject.fetch(:syslog_drain_url)).to eq('syslog://example.com:514')
        end
      end
    end

    describe '#to_hash' do
      let(:result) { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

      it 'presents the service binding as a hash' do
        expect(result).to be_instance_of(Hash)

        expect(result).to have_key(:label)
        expect(result).to have_key(:name)
        expect(result).to have_key(:credentials)
        expect(result).to have_key(:plan)
        expect(result).to have_key(:provider)
        expect(result).to have_key(:tags)
      end

      specify do
        expect(result.fetch(:credentials)).to eq(service_binding.credentials)
      end
    end
  end

  context 'for a provided service instance' do
    let(:service_instance) do
      VCAP::CloudController::UserProvidedServiceInstance.make
    end

    let(:service_binding) do
      VCAP::CloudController::ServiceBinding.make(service_instance: service_instance)
    end

    describe '#to_hash' do
      subject { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

      it { is_expected.to be_instance_of(Hash) }
      it { is_expected.to have_key(:label) }
      it { is_expected.to have_key(:credentials) }
      it { is_expected.to have_key(:tags) }
    end
  end
end
