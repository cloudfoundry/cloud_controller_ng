require_relative 'spec_helper'

describe VCAP::CloudController::Models::ProvidedServiceInstance do
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
end
