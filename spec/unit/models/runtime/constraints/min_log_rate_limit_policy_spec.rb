require 'spec_helper'

RSpec.describe MinLogRateLimitPolicy do
  let(:process) { VCAP::CloudController::ProcessModelFactory.make }

  subject(:validator) { MinLogRateLimitPolicy.new(process) }

  it 'when requested size is negative 2' do
    allow(process).to receive(:log_rate_limit).and_return(-2)
    expect(validator).to validate_with_error(process, :log_rate_limit, MinLogRateLimitPolicy::ERROR_MSG)
  end

  it 'when requested size is negative 1' do
    allow(process).to receive(:log_rate_limit).and_return(-1)
    expect(validator).to validate_without_error(process)
  end

  it 'when requested size is zero' do
    allow(process).to receive(:log_rate_limit).and_return(0)
    expect(validator).to validate_without_error(process)
  end

  it 'when requested size is positive' do
    allow(process).to receive(:log_rate_limit).and_return(1)
    expect(validator).to validate_without_error(process)
  end
end
