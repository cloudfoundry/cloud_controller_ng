require 'db_spec_helper'
require 'support/link_helpers'
require 'presenters/v3/service_usage_event_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::ServiceUsageEventPresenter do
  include LinkHelpers

  let(:usage_event) { VCAP::CloudController::ServiceUsageEvent.make }

  describe '#to_hash' do
    let(:result) { described_class.new(usage_event).to_hash }

    it 'presents the usage event' do
      expect(result[:guid]).to eq(usage_event.guid)
      expect(result[:created_at]).to eq(usage_event.created_at)
      expect(result[:updated_at]).to eq(usage_event.created_at)
      expect(result[:state]).to eq usage_event.state
      expect(result[:space][:guid]).to eq usage_event.space_guid
      expect(result[:space][:name]).to eq usage_event.space_name
      expect(result[:organization][:guid]).to eq usage_event.org_guid
      expect(result[:service_instance][:guid]).to eq usage_event.service_instance_guid
      expect(result[:service_instance][:name]).to eq usage_event.service_instance_name
      expect(result[:service_instance][:type]).to eq usage_event.service_instance_type
      expect(result[:service_plan][:guid]).to eq usage_event.service_plan_guid
      expect(result[:service_plan][:name]).to eq usage_event.service_plan_name
      expect(result[:service_offering][:guid]).to eq usage_event.service_guid
      expect(result[:service_offering][:name]).to eq usage_event.service_label
      expect(result[:service_broker][:guid]).to eq usage_event.service_broker_guid
      expect(result[:service_broker][:name]).to eq usage_event.service_broker_name
      expect(result[:links][:self][:href]).to eq "#{link_prefix}/v3/service_usage_events/#{usage_event.guid}"
    end
  end
end
