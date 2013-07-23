require_relative 'spec_helper'

describe VCAP::CloudController::Models::UserProvidedServiceInstance do
  it_behaves_like "a model with an encrypted attribute" do
    def new_model
      described_class.create(
        :name => Sham.name,
        :space => VCAP::CloudController::Models::Space.make,
        :credentials => value_to_encrypt,
      )
    end

    let(:encrypted_attr) { :credentials }
  end

  describe "#create" do
    it "saves with is_gateway_service false" do
      instance = described_class.create(
        name: 'awesome-service',
        space: VCAP::CloudController::Models::Space.make,
        credentials: {"foo" => "bar"}
      )
      instance.refresh.is_gateway_service.should be_false
    end
  end

  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :space, :credentials],
    :stripped_string_attributes => :name,
    many_to_one: {
      space: {
        delete_ok: true,
        create_for: proc { VCAP::CloudController::Models::Space.make },
      },
    },
  } do
    before(:all) do
      # encrypted attributes with changing keys, duh
      described_class.dataset.destroy
    end
  end

  describe "#as_summary_json" do
    it "contains name and guid" do
      instance = described_class.new(guid: "ABCDEFG12", name: "Random-Number-Service")
      instance.as_summary_json.should == {
        "guid" => "ABCDEFG12",
        "name" => "Random-Number-Service",
      }
    end
  end

  describe "validations" do
    it "should not bind an app and a service instance from different app spaces" do
      service_instance = described_class.make
      VCAP::CloudController::Models::App.make(:space => service_instance.space)
      service_binding = VCAP::CloudController::Models::ServiceBinding.make
      expect {
        service_instance.add_service_binding(service_binding)
      }.to raise_error VCAP::CloudController::Models::ServiceInstance::InvalidServiceBinding
    end
  end

  describe "#create_binding" do
    let(:app) { VCAP::CloudController::Models::App.make }
    let(:instance) { described_class.make(space: app.space, credentials: {a: 'b'}) }
    let(:binding_options) { Sham.binding_options }

    it 'creates a service binding' do
      new_binding = instance.create_binding(app.guid, binding_options)
      new_binding.app_id.should == app.id
      new_binding.binding_options.should == binding_options
    end

    it 'has the same credentials as the service instance' do
      new_binding = instance.create_binding(app.guid, binding_options)
      new_binding.credentials.should == {'a' => 'b'}
    end
  end

  describe "#bindable?" do
    let(:service_instance) { described_class.make }
    specify { service_instance.should be_bindable }
  end
end
