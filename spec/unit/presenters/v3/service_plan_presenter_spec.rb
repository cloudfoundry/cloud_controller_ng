require 'spec_helper'
require 'presenters/v3/service_plan_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServicePlanPresenter do
  let(:guid) { 'some-plan-guid' }

  let(:service_plan) do
    VCAP::CloudController::ServicePlan.make(guid: guid)
  end

  describe '#to_hash' do
    let(:result) { described_class.new(service_plan).to_hash }

    it 'presents the service plan' do
      expect(result).to eq({
        'guid': guid,
      })
    end
  end
end
