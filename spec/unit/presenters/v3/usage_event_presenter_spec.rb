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
        expect(result[:data][:state][:current]).to eq usage_event.state
        expect(result[:data][:state][:previous]).to eq nil
        expect(result[:data][:app][:guid]).to eq usage_event.parent_app_guid
        expect(result[:data][:app][:name]).to eq usage_event.parent_app_name
        expect(result[:data][:process][:guid]).to eq usage_event.app_guid
        expect(result[:data][:process][:type]).to eq usage_event.process_type
        expect(result[:data][:space][:guid]).to eq usage_event.space_guid
        expect(result[:data][:space][:name]).to eq usage_event.space_name
        expect(result[:data][:organization][:guid]).to eq usage_event.org_guid
        expect(result[:data][:organization][:name]).to eq nil
        expect(result[:data][:buildpack][:guid]).to eq usage_event.buildpack_guid
        expect(result[:data][:buildpack][:name]).to eq usage_event.buildpack_name
        expect(result[:data][:task][:guid]).to eq nil
        expect(result[:data][:task][:name]).to eq nil
        expect(result[:data][:memory_in_mb_per_instance][:current]).to eq usage_event.memory_in_mb_per_instance
        expect(result[:data][:memory_in_mb_per_instance][:previous]).to eq nil
        expect(result[:data][:instance_count][:current]).to eq usage_event.instance_count
        expect(result[:data][:instance_count][:previous]).to eq nil
      end
    end

    context "when it's a service usage event" do
      let(:usage_event) { VCAP::CloudController::UsageEvent.find(guid: service_usage_event.guid) }

      it 'presents the usage event' do
        expect(result[:guid]).to eq(usage_event.guid)
        expect(result[:created_at]).to eq(usage_event.created_at)
        expect(result[:updated_at]).to eq(usage_event.updated_at)
        expect(result[:type]).to eq('service')
        expect(result[:data]).to be_nil
      end
    end
  end
end
