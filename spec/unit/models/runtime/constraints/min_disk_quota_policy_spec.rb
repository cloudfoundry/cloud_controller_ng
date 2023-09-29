require 'spec_helper'

RSpec.describe MinDiskQuotaPolicy do
  subject(:validator) { MinDiskQuotaPolicy.new(process) }

  let(:process) { VCAP::CloudController::ProcessModelFactory.make }

  it 'when requested size is negative' do
    allow(process).to receive(:disk_quota).and_return(-1)
    expect(validator).to validate_with_error(process, :disk_quota, MinDiskQuotaPolicy::ERROR_MSG)
  end

  it 'when requested size is zero' do
    allow(process).to receive(:disk_quota).and_return(0)
    expect(validator).to validate_with_error(process, :disk_quota, MinDiskQuotaPolicy::ERROR_MSG)
  end

  it 'when requested size is positive' do
    allow(process).to receive(:disk_quota).and_return(1)
    expect(validator).to validate_without_error(process)
  end
end
