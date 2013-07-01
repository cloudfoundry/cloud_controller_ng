require_relative "../spec_helper"

describe VCAP::CloudController::Models::ServiceInstance do
  describe "#create" do
    let(:service_instance_attrs)  do
      {
        name: "my favorite service",
        credentials: {},
        space: VCAP::CloudController::Models::Space.make
      }
    end


    describe "when is_gateway_service is false" do
       it "returns a ProvidedServiceInstance" do
         service_instance_attrs[:is_gateway_service] = false
         service_instance = described_class.create(service_instance_attrs)
         described_class.find(guid: service_instance.guid).class.should == VCAP::CloudController::Models::ProvidedServiceInstance
       end
     end

    describe "when is_gateway_service is true" do
      it "returns a ManagedServiceInstance" do
        service_instance_attrs[:is_gateway_service] = true
        service_instance = described_class.create(service_instance_attrs)
        described_class.find(guid: service_instance.guid).class.should == VCAP::CloudController::Models::ManagedServiceInstance
      end
    end

  end
end
