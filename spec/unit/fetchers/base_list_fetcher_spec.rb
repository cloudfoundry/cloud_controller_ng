require 'spec_helper'
require 'messages/events_list_message'
require 'fetchers/event_list_fetcher'

module VCAP::CloudController
  RSpec.describe BaseListFetcher do
    subject { BaseListFetcher.filter(message, Event.dataset, Event) }
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

      context 'filtering guids' do
        let!(:event_1) { Event.make(guid: '1') }
        let!(:event_2) { Event.make(guid: '2') }

        let(:filters) do
          { guids: ['1', '3'] }
        end

        it 'returns records with matching guids' do
          expect(subject).to match_array([event_1])
        end
      end

      context 'filtering timestamps on creation' do
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

      context 'filtering timestamps on update' do
        before do
          Event.plugin :timestamps, update_on_create: false
        end

        let!(:event_1) { Event.make(guid: '1', updated_at: '2020-05-26T18:47:01Z') }
        let!(:event_2) { Event.make(guid: '2', updated_at: '2020-05-26T18:47:02Z') }
        let!(:event_3) { Event.make(guid: '3', updated_at: '2020-05-26T18:47:03Z') }
        let!(:event_4) { Event.make(guid: '4', updated_at: '2020-05-26T18:47:04Z') }

        after do
          Event.plugin :timestamps, update_on_create: true
        end

        context 'requesting events less than a timestamp' do
          let(:filters) do
            { updated_ats: { lt: event_3.updated_at.iso8601 } }
          end

          it 'returns events with a updated_at timestamp less than the given timestamp' do
            expect(subject).to match_array([event_1, event_2])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_1, event_2])
            end
          end
        end

        context 'requesting events less than or equal to a timestamp' do
          let(:filters) do
            { updated_ats: { lte: event_3.updated_at.iso8601 } }
          end

          it 'returns events with a updated_at timestamp before or at a given timestamp' do
            expect(subject).to match_array([event_1, event_2, event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_1, event_2, event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events greater than or equal to a timestamp' do
          let(:filters) do
            { updated_ats: { gte: event_3.updated_at.iso8601 } }
          end

          it 'returns events with a updated_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_3, event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_3, event_between_3_and_4, event_4])
            end
          end
        end

        context 'requesting events greater than a timestamp' do
          let(:filters) do
            { updated_ats: { gt: event_3.updated_at.iso8601 } }
          end

          it 'returns events with a updated_at timestamp greater than the given timestamp' do
            expect(subject).to match_array([event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_4])
            end
          end
        end

        context 'requesting events greater than one timestamp and less than another timestamp' do
          let(:filters) do
            { updated_ats: { gt: event_1.updated_at.iso8601, lt: event_4.updated_at.iso8601 } }
          end

          it 'returns events with a updated_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_2, event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp before or at a given timestamp' do
              expect(subject).to match_array([event_2, event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events equal to a timestamp' do
          let(:filters) do
            { updated_ats: [event_3.updated_at.iso8601] }
          end

          it 'returns events with a updated_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_3])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_3_and_4) { Event.make(guid: '3.5', updated_at: '2020-05-26T18:47:03.5Z') }

            it 'returns events with a updated_at timestamp at a given timestamp' do
              expect(subject).to match_array([event_3, event_between_3_and_4])
            end
          end
        end

        context 'requesting events equal to several timestamps' do
          let!(:event_5) { Event.make(guid: '5', updated_at: '2020-05-26T18:47:05Z') }
          let(:filters) do
            { updated_ats: [event_2.updated_at.iso8601, event_4.updated_at.iso8601] }
          end

          it 'returns events with a updated_at timestamp at or after a given timestamp' do
            expect(subject).to match_array([event_2, event_4])
          end

          context 'when there are events with subsecond timestamps' do
            let!(:event_between_2_and_3) { Event.make(guid: '2.5', updated_at: '2020-05-26T18:47:02.5Z') }

            it 'returns events with a updated_at timestamp at a given timestamp' do
              expect(subject).to match_array([event_2, event_between_2_and_3, event_4])
            end
          end
        end
      end
    end
  end
end
