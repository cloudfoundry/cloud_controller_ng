require_relative 'spec_helper'

describe VCAP::CloudController::Models::ProvidedServiceInstance do
  subject(:instance) { described_class.new }

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
end
