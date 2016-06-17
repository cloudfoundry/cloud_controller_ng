require 'spec_helper'

RSpec.describe MaxDiskQuotaPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }
  let(:max_mb) { 10 }

  subject(:validator) { MaxDiskQuotaPolicy.new(app, max_mb) }

  it 'when requested size is larger than the space allocated to the app' do
    allow(app).to receive(:disk_quota).and_return(100)
    expect(validator).to validate_with_error(app, :disk_quota, MaxDiskQuotaPolicy::ERROR_MSG % max_mb)
  end

  it 'when requested size is smaller than the space allocated to the app' do
    allow(app).to receive(:disk_quota).and_return(1)
    expect(validator).to validate_without_error(app)
  end

  it 'when requested size is equal to the space allocated to the app' do
    allow(app).to receive(:disk_quota).and_return(max_mb)
    expect(validator).to validate_without_error(app)
  end
end
