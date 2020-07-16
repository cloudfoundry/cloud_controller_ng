require 'spec_helper'
require 'presenters/v3/event_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::EventPresenter do
  let(:event) { VCAP::CloudController::Event.make }

  describe '#to_hash' do
    let(:result) { described_class.new(event).to_hash }

    context 'when optional fields are present' do
      it 'presents the event with those fields' do
        expect(result[:guid]).to eq(event.guid)
        expect(result[:created_at]).to eq(event.timestamp)
        expect(result[:updated_at]).to eq(event.timestamp)
        expect(result[:type]).to eq(event.type)
        expect(result[:actor][:guid]).to eq(event.actor)
        expect(result[:actor][:type]).to eq(event.actor_type)
        expect(result[:actor][:name]).to eq(event.actor_name)
        expect(result[:target][:guid]).to eq(event.target)
        expect(result[:target][:type]).to eq(event.target_type)
        expect(result[:target][:name]).to eq(event.target_name)
        expect(result[:data]).to eq(event.data)
        expect(result[:space]).to be_nil
        expect(result[:organization][:guid]).to eq(event.organization_guid)
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/audit_events/#{event.guid}")
      end
    end

    context 'when optional fields are missing' do
      before do
        event.actor = nil
        event.actor_type = nil
        event.actor_name = nil
        event.actee = nil
        event.actee_type = nil
        event.actee_name = nil
        event.space = nil
        event.organization_guid = nil
        event.metadata = nil
      end

      it 'still presents their keys with nil values' do
        expect(result.fetch(:actor)).to be_nil
        expect(result.fetch(:target)).to be_nil
        expect(result.fetch(:space)).to be_nil
        expect(result.fetch(:organization)).to be_nil
      end

      it 'still presents all other values' do
        expect(result[:created_at]).to eq(event.timestamp)
        expect(result[:updated_at]).to eq(event.timestamp)
        expect(result[:type]).to eq(event.type)
        expect(result[:data]).to eq({})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/audit_events/#{event.guid}")
      end
    end
  end
end
