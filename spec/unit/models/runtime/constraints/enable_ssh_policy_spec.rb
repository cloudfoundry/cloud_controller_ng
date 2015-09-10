require 'spec_helper'

describe EnableSshPolicy do
  let(:space) { VCAP::CloudController::Space.make(allow_ssh: true) }
  let(:app) { VCAP::CloudController::AppFactory.make(space: space) }
  let(:error_name) { 'enable_ssh must be false due to global allow_ssh setting' }
  subject(:validator) { EnableSshPolicy.new(app) }

  before do
    allow(VCAP::CloudController::Config.config).to receive(:[]).with(anything).and_call_original
    allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return(true)
  end

  it 'is valid when enable_ssh is false' do
    app.enable_ssh = false
    expect(validator).to validate_without_error(app)
  end

  it 'is valid when ssh is enabled globally and allowed on the space' do
    app.enable_ssh = false
    expect(validator).to validate_without_error(app)
  end

  it 'is invalid when ssh is disabled globally' do
    allow(VCAP::CloudController::Config.config).to receive(:[]).with(:allow_app_ssh_access).and_return(false)
    app.enable_ssh = true

    expect(validator).to validate_with_error(app, :enable_ssh, error_name)
  end

  it 'is invalid when space does not allow ssh access' do
    space.allow_ssh = false
    space.save
    app.enable_ssh = true

    expect(validator).to validate_with_error(app, :enable_ssh, error_name)
  end
end
