require 'spec_helper'
require 'messages/events_list_message'
require 'fetchers/event_list_fetcher'

module VCAP::CloudController
  RSpec.describe EventListFetcher do
    subject { EventListFetcher.fetch_all(message, Event.dataset) }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:gt_params) { [] }
    let(:lt_params) { [] }
    let(:message) { EventsListMessage.send(:new, filters, { gt_params: gt_params, lt_params: lt_params }) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let(:user) { User.make }
      let(:user_audit_info) { UserAuditInfo.new(user_guid: user.guid, user_email: 'user@example.com') }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space: space) }

      let!(:unscoped_event) {
        VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete('dir', 'key')
      }
      let!(:org_scoped_event) {
        VCAP::CloudController::Repositories::OrganizationEventRepository.new.record_organization_create(
          org,
          user_audit_info,
          { key: 'val' }
        )
      }
      let!(:space_scoped_event) {
        VCAP::CloudController::Repositories::AppEventRepository.new.record_app_restart(
          app_model,
          user_audit_info,
        )
      }

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

      context 'filter by created_at' do
        let(:newest) { Time.now.utc - 30.minutes }
        let(:middlest) { newest - 30.minutes }
        let(:oldest) { middlest - 30.minutes }

        let!(:new_event) { Event.make timestamp: newest, type: 'timestamp.event' }
        let!(:middle_event_1) { Event.make timestamp: middlest, type: 'timestamp.event' }
        let!(:middle_event_2) { Event.make timestamp: middlest, type: 'timestamp.event' }
        let!(:old_event) { Event.make timestamp: oldest, type: 'timestamp.event' }

        let(:filters) do
          { created_ats: [newest.iso8601, oldest.iso8601] }
        end

        it 'returns filtered events' do
          expect(subject).to match_array([new_event, old_event])
        end

        describe 'filtering for events older than the given time' do
          let(:filters) { { created_ats: [middlest.iso8601], types: ['timestamp.event'] } }
          let(:gt_params) { ['created_ats'] }

          it 'returns filtered events' do
            expect(subject).to have(1).items
            expect(subject).to match_array([new_event])
          end
        end

        describe 'filtering for events newer than the given time' do
          let(:filters) { { created_ats: [middlest.iso8601], types: ['timestamp.event'] } }
          let(:lt_params) { ['created_ats'] }

          it 'returns filtered events' do
            expect(subject).to have(1).items
            expect(subject).to match_array([old_event])
          end
        end
      end
    end
  end
end
