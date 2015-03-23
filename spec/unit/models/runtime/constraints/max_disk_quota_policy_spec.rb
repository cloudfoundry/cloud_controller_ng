require 'spec_helper'

describe MaxDiskQuotaPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(disk_quota: 100, state: 'STARTED') }
  let(:space) { double(:space, has_remaining_disk_quota: false) }
  let(:error_name) { :random_disk_quota_error }

  subject(:validator) { MaxDiskQuotaPolicy.new(app, space, error_name) }

  context 'when performing a scaling operation' do
    before do
      app.disk_quota = 150
    end

    it 'registers error when disk_quota is exceeded' do
      allow(space).to receive(:has_remaining_disk_space).with(50).and_return(false)
      expect(validator).to validate_with_error(app, :disk_quota, error_name)
    end

    it 'does not register error when disk_quota is not exceeded' do
      allow(space).to receive(:has_remaining_disk_space).with(50).and_return(true)
      expect(validator).to validate_without_error(app)
    end

    it 'adds the given error to the model' do
      allow(space).to receive(:has_remaining_disk_space).with(50).and_return(false)
      validator.validate
      expect(app.errors.on(:disk_quota)).to include(error_name)
    end
  end

  context 'when not performing a scaling operation' do
    it 'does not register error' do
      app.state = 'STOPPED'
      expect(validator).to validate_without_error(app)
    end
  end
end
