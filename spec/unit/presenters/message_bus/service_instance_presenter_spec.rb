require 'spec_helper'
require 'presenters/message_bus/service_instance_presenter'

describe ServiceInstancePresenter do
  describe '#to_hash' do
    subject { ServiceInstancePresenter.new(service_instance).to_hash }

    context 'for a managed service instance' do
      let(:service_instance) do
        VCAP::CloudController::ManagedServiceInstance.make(service_plan: service_plan, tags: ['meow'])
      end

      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(service: service)
      end

      let(:service) { VCAP::CloudController::Service.make(tags: ['relational', 'mysql']) }

      it { is_expected.to have_key(:label) }
      it { is_expected.to have_key(:provider) }
      it { is_expected.to have_key(:plan) }
      it { is_expected.to have_key(:name) }
      it { is_expected.to have_key(:tags) }

      specify do
        expect(subject[:label]).to eq(service_instance.service.label)
        expect(subject[:provider]).to eq(service_instance.service.provider)
        expect(subject[:plan]).to eq(service_instance.service_plan.name)
        expect(subject[:name]).to eq(service_instance.name)
        expect(subject[:tags]).to eq(['relational', 'mysql', 'meow'])
      end
    end

    context 'for a provided service instance' do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

      specify do
        expect(subject[:label]).to eq('user-provided')
        expect(subject[:name]).to eq(service_instance.name)
        expect(subject[:tags]).to eq([])
      end
    end
  end
end
