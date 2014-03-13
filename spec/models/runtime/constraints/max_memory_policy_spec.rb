require "spec_helper"

describe MaxMemoryPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }
  let(:organization) { double("organization") }

  subject(:validator) { MaxMemoryPolicy.new(app, organization)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
    allow(organization).to receive(:memory_remaining).and_return(1028)
    allow(app).to receive(:additional_memory_requested).and_return(128)
  end

  it "registers error when quota is exceeded" do
    allow(organization).to receive(:memory_remaining).and_return(65)
    expect(validator).to validate_with_error(app, :quota_exceeded)
  end

  it "does not register error when quota is not exceeded" do
    expect(validator).to validate_without_error(app)
  end
end
