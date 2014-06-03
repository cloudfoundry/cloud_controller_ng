require "spec_helper"

describe DiskQuotaPolicy do
  let(:app) { double("app") }
  let(:errors) { {} }
  let(:max_mb) { 10 }

  subject(:validator) { DiskQuotaPolicy.new(app, max_mb)}
  before do
    allow(app).to receive(:errors).and_return(errors)
    allow(errors).to receive(:add) {|k, v| errors[k] = v  }
  end

  it "when requested size is larger than the space allocated to the app" do
    allow(app).to receive(:disk_quota).and_return(100)
    expect(validator).to validate_with_error(app, DiskQuotaPolicy::ERROR_MSG % max_mb)
  end

  it "when requested size is smaller than the space allocated to the app" do
    allow(app).to receive(:disk_quota).and_return(1)
    expect(validator).to validate_without_error(app)
  end

  it "when requested size is equal to the space allocated to the app" do
    allow(app).to receive(:disk_quota).and_return(max_mb)
    expect(validator).to validate_without_error(app)
  end
end
