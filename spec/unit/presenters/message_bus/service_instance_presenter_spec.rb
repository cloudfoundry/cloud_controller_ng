require 'spec_helper'
require 'presenters/message_bus/service_instance_presenter'

describe ServiceInstancePresenter do

  describe "#to_hash" do
    subject { ServiceInstancePresenter.new(service_instance).to_hash }

    context "for a managed service instance" do
      let(:service_instance) do
        VCAP::CloudController::ManagedServiceInstance.make(service_plan: service_plan)
      end

      let(:service_plan) do
        VCAP::CloudController::ServicePlan.make(service: service)
      end

      let(:service) { VCAP::CloudController::Service.make(tags: ["relational", "mysql"]) }

      specify do
        expect(subject.keys).to include(:label)
        expect(subject.keys).to include(:provider)
        expect(subject.keys).to include(:version)
        expect(subject.keys).to include(:vendor)
        expect(subject.keys).to include(:plan)
        expect(subject.keys).to include(:name)
        expect(subject).to have_key(:tags)
      end

      specify do
        expect(subject.fetch(:label)).to eq([service_instance.service.label, service_instance.service.version].join('-'))
        expect(subject.fetch(:provider)).to eq(service_instance.service.provider)
        expect(subject.fetch(:version)).to eq(service_instance.service.version)
        expect(subject.fetch(:vendor)).to eq(service_instance.service.label)
        expect(subject.fetch(:plan)).to eq(service_instance.service_plan.name)
        expect(subject.fetch(:name)).to eq(service_instance.name)
        expect(subject.fetch(:tags)).to eq(["relational", "mysql"])
      end


      context 'when the service does not have a version' do
        let(:service) { VCAP::CloudController::Service.make(version: nil) }

        specify { expect(subject).not_to have_key(:version) }

        its([:label]) { should == service.label }
      end
    end

    context "for a provided service instance" do
      let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

      specify do
        expect(subject.keys).to eq([:label, :name, :tags])
      end

      specify do
        expect(subject.fetch(:label)).to eq("user-provided")
        expect(subject.fetch(:name)).to eq(service_instance.name)
        expect(subject.fetch(:tags)).to eq([])
      end
    end
  end
end
