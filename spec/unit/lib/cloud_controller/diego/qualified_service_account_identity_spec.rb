require 'spec_helper'
require 'cloud_controller/diego/service_account_identity'

module VCAP::CloudController::Diego
  RSpec.describe 'Qualified runtime account identity' do
    it 'encodes the immutable prefix for an entitled app in another space' do
      org = create(:organization, service_account_prefix: 'payments-team')
      source = create(:space, organization: org)
      target = create(:space, organization: org)
      account = VCAP::CloudController::ServiceAccountModel.create(name: 'worker-app', space: source, status: 'ready')
      account.add_entitled_space(target)
      app = create(:app_model, space: target, service_account: account)
      TestConfig.override(service_account_runtime_enabled: true)

      properties = ServiceAccountIdentity.new(app, TestConfig.config_instance).certificate_properties
      expect(properties.service_account.to_h).to include(name: 'worker-app', prefix: 'payments-team')
    end
  end
end
