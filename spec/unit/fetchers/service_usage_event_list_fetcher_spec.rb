require 'db_spec_helper'
require 'messages/service_usage_events_list_message'
require 'fetchers/service_usage_event_list_fetcher'

module VCAP::CloudController
  RSpec.describe ServiceUsageEventListFetcher do
    subject { ServiceUsageEventListFetcher.fetch_all(message, ServiceUsageEvent.dataset) }
    let(:message) { ServiceUsageEventsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let!(:service_usage_event) { VCAP::CloudController::ServiceUsageEvent.make }
      let!(:service_usage_event_2) { VCAP::CloudController::ServiceUsageEvent.make }
      let!(:service_usage_event_3) { VCAP::CloudController::ServiceUsageEvent.make }

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      it 'returns all of the events' do
        expect(subject.count).to eq(3)
        expect(subject).to match_array([service_usage_event, service_usage_event_2, service_usage_event_3])
      end

      context 'filtering by after_guid' do
        let(:filters) do
          { after_guid: [service_usage_event_2.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event_3])
        end

        context 'when the given guid is invalid' do
          let(:filters) do
            { after_guid: 'something-invalid' }
          end

          it 'returns filtered events' do
            expect { subject }.to raise_error /After guid filter must be a valid service usage event guid./
          end
        end
      end

      context 'filtering by guid' do
        let(:filters) do
          { guids: [service_usage_event.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event])
        end
      end

      context 'filtering by service_instance_type' do
        let(:filters) do
          { service_instance_types: [service_usage_event_2.service_instance_type] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event_2])
        end
      end

      context 'filtering by service offering guid' do
        let(:filters) do
          { service_offering_guids: [service_usage_event_2.service_guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([service_usage_event_2])
        end
      end
    end
  end
end
