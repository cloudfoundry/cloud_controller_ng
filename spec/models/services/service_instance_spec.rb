require "spec_helper"

describe VCAP::CloudController::ServiceInstance, type: :model do
  describe "#create" do
    let(:service_instance_attrs)  do
      {
        name: "my favorite service",
        credentials: {},
        space: VCAP::CloudController::Space.make
      }
    end

    let(:create_instance) { described_class.create(service_instance_attrs) }

    context "when the name is longer than 50 characters" do
      let(:very_long_name){ 's' * 51 }
      it "refuses to create this service instance" do
        service_instance_attrs[:name] = very_long_name
        expect {create_instance}.to raise_error Sequel::ValidationFailed
      end
    end

    describe "when is_gateway_service is false" do
      it "returns a UserProvidedServiceInstance" do
        service_instance_attrs[:is_gateway_service] = false
        service_instance = described_class.create(service_instance_attrs)
        described_class.find(guid: service_instance.guid).class.should == VCAP::CloudController::UserProvidedServiceInstance
      end
    end

    describe "when is_gateway_service is true" do
      it "returns a ManagedServiceInstance" do
        service_instance_attrs[:is_gateway_service] = true
        service_instance = described_class.create(service_instance_attrs)
        described_class.find(guid: service_instance.guid).class.should == VCAP::CloudController::ManagedServiceInstance
      end
    end
  end

  describe "#type" do
    it "returns the model name for API consumption" do
      managed_instance = VCAP::CloudController::ManagedServiceInstance.new
      expect(managed_instance.type).to eq "managed_service_instance"

      user_provided_instance = VCAP::CloudController::UserProvidedServiceInstance.new
      expect(user_provided_instance.type).to eq "user_provided_service_instance"
    end
  end

  describe '#bindable?' do
    it { should be_bindable }
  end

  describe '#as_summary_json' do
    it 'contains name, guid, and binding count' do
      instance = VCAP::CloudController::ServiceInstance.make(guid: 'ABCDEFG12', name: 'Random-Number-Service')
      VCAP::CloudController::ServiceBinding.make(service_instance: instance)

      instance.as_summary_json.should == {
        'guid' => 'ABCDEFG12',
        'name' => 'Random-Number-Service',
        'bound_app_count' => 1
      }
    end
  end
end
