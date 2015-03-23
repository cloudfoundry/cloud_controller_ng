require 'spec_helper'

describe MinDiskQuotaPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(disk_quota: 64) }

  subject(:validator) { MinDiskQuotaPolicy.new(app) }

  it 'registers error when requested disk quota is 0' do
    app.disk_quota = 0
    expect(validator).to validate_with_error(app, :disk_quota, :zero_or_less)
  end

  it 'registers error when requested disk quota is negative' do
    app.disk_quota = -1
    expect(validator).to validate_with_error(app, :disk_quota, :zero_or_less)
  end

  it 'does not register error when requested disk quota is positive' do
    app.disk_quota = 1
    expect(validator).to validate_without_error(app)
  end
end
