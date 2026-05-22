require 'spec_helper'

RSpec.describe FactoryBot do
  describe '.lint' do
    before do
      UAARequests.stub_all
      routing_api_client = instance_double(
        VCAP::CloudController::RoutingApi::Client,
        router_group: VCAP::CloudController::RoutingApi::RouterGroup.new(
          'guid' => 'tcp-router-group',
          'type' => 'tcp',
          'reservable_ports' => '1000-65535'
        ),
        enabled?: true
      )
      allow_any_instance_of(CloudController::DependencyLocator).to receive(:routing_api_client).and_return(routing_api_client)
    end

    it 'succeeds for every factory and trait combination' do
      FactoryBot.lint(traits: true)
    end
  end
end
