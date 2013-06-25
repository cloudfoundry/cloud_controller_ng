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

  it_behaves_like 'attribute normalization', {
    stripped_string_attributes: [:name],
  }
end
