require 'spec_helper'
require 'cloud_controller/presenters/service_binding_presenter'

describe ServiceBindingPresenter do
  let(:service) { VCAP::CloudController::Models::Service.make(label: Sham.label) }
  let(:service_plan) { VCAP::CloudController::Models::ServicePlan.make(name: Sham.name, service: service) }
  let(:service_instance) do
    VCAP::CloudController::Models::ManagedServiceInstance.make(name: Sham.name,
                                                              service_plan: service_plan)
  end
  let(:service_binding) do
    VCAP::CloudController::Models::ServiceBinding.make(service_instance: service_instance)
  end

  describe "#to_hash" do

    subject { ServiceBindingPresenter.new(service_binding).to_hash }
    specify do
      subject.should be_instance_of(Hash)
      subject.should have_key(:label)
      subject.should have_key(:name)
      subject.should have_key(:credentials)
      subject.should have_key(:options)
      subject.should have_key(:plan)
      subject.should have_key(:provider)
      subject.should have_key(:version)
      subject.should have_key(:vendor)
    end

    specify "should " do
      subject.fetch(:label).should == [service.label, service.version].join('-')
      subject.fetch(:name).should == service_instance.name
      subject.fetch(:credentials).should == service_binding.credentials
      subject.fetch(:options).should == service_binding.binding_options
      subject.fetch(:plan).should == service_plan.name
      subject.fetch(:provider).should == service.provider
      subject.fetch(:version).should == service.version
      subject.fetch(:vendor).should == service.label
    end
  end
end
