require 'spec_helper'

RSpec.describe MaxDiskQuotaPolicy do
  let(:process) { VCAP::CloudController::ProcessModelFactory.make }
  let(:max_mb) { 10 }

  subject(:validator) { MaxDiskQuotaPolicy.new(process, max_mb) }

  it 'when requested size is larger than the space allocated to the app' do
    allow(process).to receive(:disk_quota).and_return(100)
    expect(validator).to validate_with_error(process, :disk_quota, sprintf(MaxDiskQuotaPolicy::ERROR_MSG, desired: 100, max: max_mb))
  end

  it 'when requested size is smaller than the space allocated to the app' do
    allow(process).to receive(:disk_quota).and_return(1)
    expect(validator).to validate_without_error(process)
  end

  it 'when requested size is equal to the space allocated to the app' do
    allow(process).to receive(:disk_quota).and_return(max_mb)
    expect(validator).to validate_without_error(process)
  end
end
