require 'spec_helper'
require 'messages/usage_events_list_message'
require 'fetchers/usage_event_list_fetcher'

module VCAP::CloudController
  RSpec.describe UsageEventListFetcher do
    subject { UsageEventListFetcher.fetch_all(message, UsageEvent.dataset) }
    let(:message) { UsageEventsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let!(:app_usage_event) do
        event = VCAP::CloudController::AppUsageEvent.make
        VCAP::CloudController::UsageEvent.find(guid: event.guid)
      end

      let!(:service_usage_event) do
        event = VCAP::CloudController::ServiceUsageEvent.make
        VCAP::CloudController::UsageEvent.find(guid: event.guid)
      end

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      it 'returns all of the events' do
        expect(subject.count).to eq(2)
        expect(subject).to match_array([app_usage_event, service_usage_event])
      end

      context 'filtering by type' do
        let(:filters) do
          { types: ['app'] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([app_usage_event])
        end
      end

      context 'filtering by guid' do
        let(:filters) do
          { guids: [app_usage_event.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([app_usage_event])
        end
      end

      context 'filtering by service_instance_type' do
        let(:filters) do
          { service_instance_types: [service_usage_event.service_instance_type] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event])
        end
      end

      context 'filtering by type' do
        let(:filters) do
          { service_offering_guids: [service_usage_event.service_guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event])
        end
      end
    end
  end
end
