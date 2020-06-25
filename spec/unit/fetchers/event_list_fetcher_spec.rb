require 'spec_helper'
require 'messages/events_list_message'
require 'fetchers/event_list_fetcher'

module VCAP::CloudController
  RSpec.describe EventListFetcher do
    subject { EventListFetcher.fetch_all(message, Event.dataset) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { EventsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space: space) }

      let!(:unscoped_event) { Event.make(actee: 'dir/key', type: 'blob.remove_orphan', organization_guid: '') }
      let!(:org_scoped_event) { Event.make(created_at: Time.now + 100, organization_guid: org.guid) }
      let!(:space_scoped_event) { Event.make(space_guid: space.guid, organization_guid: org.guid, actee: app_model.guid, type: 'audit.app.restart') }

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      it 'returns all of the events' do
        expect(subject).to match_array([unscoped_event, org_scoped_event, space_scoped_event])
      end

      context 'filtering by type' do
        let(:filters) do
          { types: ['audit.app.restart'] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([space_scoped_event])
        end
      end

      context 'filtering by target guid' do
        let(:filters) do
          { target_guids: [app_model.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([space_scoped_event])
        end
      end

      context 'filtering by space guid' do
        let(:filters) do
          { space_guids: [space.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([space_scoped_event])
        end
      end

      context 'filtering by org guid' do
        let(:filters) do
          { organization_guids: [org.guid] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([org_scoped_event, space_scoped_event])
        end
      end

      context 'requesting events less than a timestamp' do
        let(:filters) do
          { created_at: { lt: (Time.now + 1).iso8601 } }
        end

        it 'returns events with a created_at timestamp less than the given timestamp' do
          expect(subject).to match_array([unscoped_event, space_scoped_event])
        end
      end

      context 'requesting events greater than a timestamp' do
        let(:filters) do
          { created_at: { gt: (Time.now + 1).iso8601 } }
        end

        it 'returns events with a created_at timestamp less than the given timestamp' do
          expect(subject).to match_array([org_scoped_event])
        end
      end
    end
  end
end
