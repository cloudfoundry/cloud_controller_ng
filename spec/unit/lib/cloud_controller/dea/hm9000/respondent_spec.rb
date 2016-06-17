require 'spec_helper'
require 'cloud_controller/dea/hm9000/respondent'

module VCAP::CloudController
  module Dea
    module HM9000
      RSpec.describe Respondent do
        let(:message_bus) { CfMessageBus::MockMessageBus.new }
        let(:dea_client) { double(VCAP::CloudController::Dea::Client) }

        subject(:respondent) { Dea::HM9000::Respondent.new(dea_client, message_bus) }
      end
    end
  end
end
