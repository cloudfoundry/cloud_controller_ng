require 'spec_helper'

describe MinDiskQuotaPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make }

  subject(:validator) { MinDiskQuotaPolicy.new(app) }

  it 'when requested size is negative' do
    allow(app).to receive(:disk_quota).and_return(-1)
    expect(validator).to validate_with_error(app, :disk_quota, MinDiskQuotaPolicy::ERROR_MSG)
  end

  it 'when requested size is zero' do
    allow(app).to receive(:disk_quota).and_return(0)
    expect(validator).to validate_with_error(app, :disk_quota, MinDiskQuotaPolicy::ERROR_MSG)
  end

  it 'when requested size is positive' do
    allow(app).to receive(:disk_quota).and_return(1)
    expect(validator).to validate_without_error(app)
  end
end
