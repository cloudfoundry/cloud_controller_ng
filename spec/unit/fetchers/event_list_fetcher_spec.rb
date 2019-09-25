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
    end
  end
end
