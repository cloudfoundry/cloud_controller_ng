require 'spec_helper'
require 'messages/app_usage_events_list_message'
require 'fetchers/app_usage_event_list_fetcher'

module VCAP::CloudController
  RSpec.describe AppUsageEventListFetcher do
    subject { AppUsageEventListFetcher.fetch_all(message, AppUsageEvent.dataset) }
    let(:message) { AppUsageEventsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let!(:app_usage_event) { VCAP::CloudController::AppUsageEvent.make }
      let!(:app_usage_event_2) { VCAP::CloudController::AppUsageEvent.make }

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      it 'returns all of the events' do
        expect(subject.count).to eq(2)
        expect(subject).to match_array([app_usage_event, app_usage_event_2])
      end

      context 'filtering by guid' do
        let(:filters) do
          { guids: [app_usage_event.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([app_usage_event])
        end
      end
    end
  end
end
