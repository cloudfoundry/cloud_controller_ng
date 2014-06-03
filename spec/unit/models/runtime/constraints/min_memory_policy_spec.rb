require "spec_helper"

describe MinMemoryPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }

  subject(:validator) { MinMemoryPolicy.new(app)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }

    allow(app).to receive(:requested_memory).and_return(64)
  end

  it "registers error when requested memory is 0" do
    allow(app).to receive(:requested_memory).and_return(0)
    expect(validator).to validate_with_error(app, :zero_or_less)
  end

  it "registers error when requested memory is negative" do
    allow(app).to receive(:requested_memory).and_return(-1)
    expect(validator).to validate_with_error(app, :zero_or_less)
  end

  it "does not register error when requested memory is positive" do
    allow(app).to receive(:requested_memory).and_return(1)
    expect(validator).to validate_without_error(app)
  end
end
