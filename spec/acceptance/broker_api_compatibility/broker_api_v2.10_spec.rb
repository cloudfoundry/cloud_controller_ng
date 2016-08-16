require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.10' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) { default_catalog(plan_updateable: true) }

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
    end

    # NOTE: the only changes in 2.10 so far are for experimental volume mounts.  Since we do not guarantee backward
    # compatibility on volume mounts, we won't add tests for that feature just yet.
  end
end
