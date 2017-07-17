require 'spec_helper'

RSpec.describe MinMemoryPolicy do
  let(:process) { VCAP::CloudController::AppFactory.make(memory: 64) }

  subject(:validator) { MinMemoryPolicy.new(process) }

  it 'registers error when requested memory is 0' do
    process.memory = 0
    expect(validator).to validate_with_error(process, :memory, :zero_or_less)
  end

  it 'registers error when requested memory is negative' do
    process.memory = -1
    expect(validator).to validate_with_error(process, :memory, :zero_or_less)
  end

  it 'does not register error when requested memory is positive' do
    process.memory = 1
    expect(validator).to validate_without_error(process)
  end
end
