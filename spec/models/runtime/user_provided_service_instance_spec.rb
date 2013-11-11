require "spec_helper"

describe VCAP::CloudController::UserProvidedServiceInstance, type: :model do
  let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make }

  it_behaves_like "a model with an encrypted attribute" do
    def new_model
      described_class.create(
        :name => Sham.name,
        :space => VCAP::CloudController::Space.make,
        :credentials => value_to_encrypt,
      )
    end

    let(:encrypted_attr) { :credentials }
  end

  describe "#create" do
    it "saves with is_gateway_service false" do
      instance = described_class.create(
        name: 'awesome-service',
        space: VCAP::CloudController::Space.make,
        credentials: {"foo" => "bar"},
      )
      instance.refresh.is_gateway_service.should be_false
    end
  end

  describe "#update" do
    it "updates associated bindings on an update" do
      service_binding = VCAP::CloudController::ServiceBinding.make( :service_instance => service_instance )
      new_drain_url = "http://newhotness.com:8080/logz"
      service_instance.update(:syslog_drain_url => new_drain_url)
      service_binding.reload
      service_binding.syslog_drain_url.should eq(new_drain_url)
    end
  end

  it_behaves_like "a CloudController model", {
    :required_attributes => [:name, :space],
    :stripped_string_attributes => [:name, :syslog_drain_url],
    many_to_one: {
      space: {
        delete_ok: true,
        create_for: proc { VCAP::CloudController::Space.make },
      },
    },
  }

  describe "serialization" do
    it "includes its type" do
      expect(Yajl::Parser.parse(service_instance.to_json).fetch("type")).to eq "user_provided_service_instance"
    end
  end

  describe "validations" do
    it "should not bind an app and a service instance from different app spaces" do
      service_instance = described_class.make
      VCAP::CloudController::AppFactory.make(:space => service_instance.space)
      service_binding = VCAP::CloudController::ServiceBinding.make
      expect {
        service_instance.add_service_binding(service_binding)
      }.to raise_error VCAP::CloudController::ServiceInstance::InvalidServiceBinding
    end
  end

  describe "#tags" do
    it 'does not have tags' do
      service_instance = described_class.make
      expect(service_instance.tags).to eq []
    end
  end
end
