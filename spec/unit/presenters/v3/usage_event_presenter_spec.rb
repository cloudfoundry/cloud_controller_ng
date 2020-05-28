require 'spec_helper'
require 'presenters/v3/usage_event_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::UsageEventPresenter do
  let(:app_usage_event) { VCAP::CloudController::AppUsageEvent.make }
  let(:service_usage_event) { VCAP::CloudController::ServiceUsageEvent.make }

  describe '#to_hash' do
    let(:result) { described_class.new(usage_event).to_hash }

    context "when it's an app usage event" do
      let(:usage_event) { VCAP::CloudController::UsageEvent.find(guid: app_usage_event.guid) }

      it 'presents the usage event' do
        expect(result[:guid]).to eq(usage_event.guid)
        expect(result[:created_at]).to eq(usage_event.created_at)
        expect(result[:updated_at]).to eq(usage_event.updated_at)
        expect(result[:type]).to eq('app')
      end
    end
    context "when it's a service usage event" do
      let(:usage_event) { VCAP::CloudController::UsageEvent.find(guid: service_usage_event.guid) }

      it 'presents the usage event' do
        expect(result[:guid]).to eq(usage_event.guid)
        expect(result[:created_at]).to eq(usage_event.created_at)
        expect(result[:updated_at]).to eq(usage_event.updated_at)
        expect(result[:type]).to eq('service')
      end
    end
  end
end
