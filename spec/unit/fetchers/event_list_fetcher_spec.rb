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

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      context 'non-timestamp filtering' do
        let!(:unscoped_event) { Event.make(actee: 'dir/key', type: 'blob.remove_orphan', organization_guid: '') }
        let!(:org_scoped_event) { Event.make(created_at: Time.now + 100, organization_guid: org.guid) }
        let!(:space_scoped_event) { Event.make(space_guid: space.guid, organization_guid: org.guid, actee: app_model.guid, type: 'audit.app.restart') }

        it 'returns all of the events without any filters' do
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
      end

      context 'timestamp filtering' do
        let!(:event_1) { Event.make(guid: '1', created_at: '2020-05-26T18:47:01Z') }
        let!(:event_2) { Event.make(guid: '2', created_at: '2020-05-26T18:47:02Z') }
        let!(:event_3) { Event.make(guid: '3', created_at: '2020-05-26T18:47:03Z') }
        let!(:event_4) { Event.make(guid: '4', created_at: '2020-05-26T18:47:04Z') }

        context 'requesting events less than a timestamp' do
          let(:filters) do
            { created_ats: { lt: event_3.created_at.iso8601 } }
          end

          it 'returns events with a created_at timestamp less than the given timestamp' do
            expect(subject).to match_array([event_1, event_2])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_1, event_2])
            end
          end
        end

        context 'requesting events less than or equal to a timestamp' do
          let(:filters) do
            { created_ats: { lte: event_3.created_at.iso8601 } }
          end

          it 'returns events with a created_at timestamp before or at a given timestamp' do
            expect(subject).to match_array([event_1, event_2, event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_1, event_2, event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events greater than or equal to a timestamp' do
          let(:filters) do
            { created_ats: { gte: event_3.created_at.iso8601 } }
          end

          it 'returns events with a created_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_3, event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_3, event_between_3_and_4, event_4])
            end
          end
        end

        context 'requesting events greater than a timestamp' do
          let(:filters) do
            { created_ats: { gt: event_3.created_at.iso8601 } }
          end

          it 'returns events with a created_at timestamp greater than the given timestamp' do
            expect(subject).to match_array([event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_4])
            end
          end
        end

        context 'requesting events greater than one timestamp and less than another timestamp' do
          let(:filters) do
            { created_ats: { gt: event_1.created_at.iso8601, lt: event_4.created_at.iso8601 } }
          end

          it 'returns events with a created_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_2, event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_2, event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events equal to a timestamp' do
          let(:filters) do
            { created_ats: [event_3.created_at.iso8601] }
          end

          it 'returns events with a created_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', created_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a created_at timestamp at a given timestamp' do
              expect(subject).to match_array([event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events equal to several timestamps' do
          let!(:event_5) { Event.make(guid: '5', created_at: '2020-05-26T18:47:05Z') }
          let(:filters) do
            { created_ats: [event_2.created_at.iso8601, event_4.created_at.iso8601] }
          end

          it 'returns events with a created_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_2, event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_2_and_3) { Event.make(guid: '2.5', created_at: '2020-05-26T18:47:02.5Z') }

            it 'returns events with a created_at timestamp at a given timestamp' do
              expect(subject).to match_array([event_2, event_between_2_and_3, event_4])
            end
          end
        end
      end
    end
  end
end
