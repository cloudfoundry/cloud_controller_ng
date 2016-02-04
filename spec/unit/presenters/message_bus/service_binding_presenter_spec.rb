require 'spec_helper'
require 'presenters/message_bus/service_binding_presenter'

describe ServiceBindingPresenter do
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
        subject { ServiceBindingPresenter.new(service_binding).to_hash }

        specify do
          expect(subject.fetch(:syslog_drain_url)).to eq('syslog://example.com:514')
        end
      end
    end

    context 'with binding options' do
      let(:binding_options) { Sham.binding_options }

      describe '#to_hash' do
        subject { ServiceBindingPresenter.new(service_binding).to_hash }

        it { is_expected.to be_instance_of(Hash) }
        it { is_expected.to have_key(:label) }
        it { is_expected.to have_key(:name) }
        it { is_expected.to have_key(:credentials) }
        it { is_expected.to have_key(:options) }
        it { is_expected.to have_key(:plan) }
        it { is_expected.to have_key(:provider) }
        it { is_expected.to have_key(:tags) }

        specify do
          expect(subject.fetch(:credentials)).to eq(service_binding.credentials)
          expect(subject.fetch(:options)).to eq(service_binding.binding_options)
        end
      end
    end

    context 'without binding options' do
      describe '#to_hash' do
        subject { ServiceBindingPresenter.new(service_binding).to_hash }

        specify do
          expect(subject.fetch(:options)).to eq({})
        end
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
      subject { ServiceBindingPresenter.new(service_binding).to_hash }

      it { is_expected.to be_instance_of(Hash) }
      it { is_expected.to have_key(:label) }
      it { is_expected.to have_key(:credentials) }
      it { is_expected.to have_key(:options) }
      it { is_expected.to have_key(:tags) }
    end
  end
end
