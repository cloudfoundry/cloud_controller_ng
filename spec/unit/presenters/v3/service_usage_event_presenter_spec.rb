require 'spec_helper'
require 'presenters/v3/service_usage_event_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServiceUsageEventPresenter do
  let(:usage_event) { VCAP::CloudController::ServiceUsageEvent.make }

  describe '#to_hash' do
    let(:result) { described_class.new(usage_event).to_hash }

    it 'presents the usage event' do
      expect(result[:guid]).to eq(usage_event.guid)
      expect(result[:created_at]).to eq(usage_event.created_at)
      expect(result[:updated_at]).to eq(usage_event.created_at)
      expect(result[:data][:state]).to eq usage_event.state
      expect(result[:data][:space][:guid]).to eq usage_event.space_guid
      expect(result[:data][:space][:name]).to eq usage_event.space_name
      expect(result[:data][:organization][:guid]).to eq usage_event.org_guid
      expect(result[:data][:service_instance][:guid]).to eq usage_event.service_instance_guid
      expect(result[:data][:service_instance][:name]).to eq usage_event.service_instance_name
      expect(result[:data][:service_instance][:type]).to eq usage_event.service_instance_type
      expect(result[:data][:service_plan][:guid]).to eq usage_event.service_plan_guid
      expect(result[:data][:service_plan][:name]).to eq usage_event.service_plan_name
      expect(result[:data][:service_offering][:guid]).to eq usage_event.service_guid
      expect(result[:data][:service_offering][:name]).to eq usage_event.service_label
      expect(result[:data][:service_broker][:guid]).to eq usage_event.service_broker_guid
      expect(result[:data][:service_broker][:name]).to eq usage_event.service_broker_name
    end
  end
end
