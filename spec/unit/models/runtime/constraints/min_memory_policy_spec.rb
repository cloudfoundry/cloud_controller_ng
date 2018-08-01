require 'spec_helper'

RSpec.describe MinMemoryPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(memory: 64) }

  subject(:validator) { MinMemoryPolicy.new(app) }

  it 'registers error when requested memory is 0' do
    app.memory = 0
    expect(validator).to validate_with_error(app, :memory, :zero_or_less)
  end

  it 'registers error when requested memory is negative' do
    app.memory = -1
    expect(validator).to validate_with_error(app, :memory, :zero_or_less)
  end

  it 'does not register error when requested memory is positive' do
    app.memory = 1
    expect(validator).to validate_without_error(app)
  end
end
