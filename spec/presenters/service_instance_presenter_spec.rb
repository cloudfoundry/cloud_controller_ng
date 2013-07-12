require 'spec_helper'
require 'cloud_controller/presenters/service_instance_presenter'

describe ServiceInstancePresenter do

  describe "#to_hash" do
    subject { ServiceInstancePresenter.new(service_instance).to_hash }

    context "for a managed service instance" do
      let(:service_instance) { VCAP::CloudController::Models::ManagedServiceInstance.make }

      specify do
        subject.keys.should include(:label)
        subject.keys.should include(:provider)
        subject.keys.should include(:version)
        subject.keys.should include(:vendor)
        subject.keys.should include(:plan)
        subject.keys.should include(:name)
      end

      specify do
        subject.fetch(:label).should == [service_instance.service.label, service_instance.service.version].join('-')
        subject.fetch(:provider).should == service_instance.service.provider
        subject.fetch(:version).should == service_instance.service.version
        subject.fetch(:vendor).should == service_instance.service.label
        subject.fetch(:plan).should == service_instance.service_plan.name
        subject.fetch(:name).should == service_instance.name
      end
    end

    context "for a provided service instance" do
      let(:service_instance) { VCAP::CloudController::Models::ProvidedServiceInstance.make }

      specify do
        subject.keys.should == [:label, :name]
      end

      specify do
        subject.fetch(:label).should == "Unmanaged Service #{service_instance.guid}"
        subject.fetch(:name).should == service_instance.name
      end
    end
  end
end
