require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EventsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:timestamp) }
      it { expect(described_class).to be_queryable_by(:type) }
      it { expect(described_class).to be_queryable_by(:actee) }
      it { expect(described_class).to be_queryable_by(:space_guid) }
      it { expect(described_class).to be_queryable_by(:organization_guid) }
    end

    it 'can order by name and id when listing' do
      expect(described_class.sortable_parameters).to match_array([:timestamp, :id])
    end

    describe 'GET /v2/events' do
      before do
        @user_a = User.make
        @user_b = User.make

        @org_a = Organization.make
        @org_b = Organization.make

        @space_a = Space.make organization: @org_a
        @space_b = Space.make organization: @org_b

        @org_a.add_user(@user_a)
        @org_b.add_user(@user_b)

        @event_a = Event.make space: @space_a
        @event_b = Event.make space: @space_b

        @service_event = Event.make(space_guid: '', organization_guid: '', type: 'audit.service_broker.create')
      end

      describe 'default order' do
        it 'sorts by timestamp' do
          type = SecureRandom.uuid
          Event.make(timestamp: Time.new(1990, 1, 1).utc, type: type, actor: 'earlier')
          Event.make(timestamp: Time.new(2000, 1, 1).utc, type: type, actor: 'later')
          Event.make(timestamp: Time.new(1995, 1, 1).utc, type: type, actor: 'middle')

          set_current_user_as_admin
          get '/v2/events'
          parsed_body = MultiJson.load(last_response.body)
          events = parsed_body['resources'].select { |r| r['entity']['type'] == type }.map { |r| r['entity']['actor'] }
          expect(events).to eq(%w(earlier middle later))
        end
      end

      context 'as an admin' do
        before { set_current_user_as_admin }

        it 'includes all events' do
          get '/v2/events'

          parsed_body = MultiJson.load(last_response.body)
          expect(parsed_body['total_results']).to eq(3)
        end
      end

      context 'as an org auditor' do
        before do
          @org_a.add_auditor(@user_a)
          expect(@user_a.spaces).to be_empty
          set_current_user(@user_a)
        end

        it 'includes only events from organizations in which the user is an auditor' do
          get '/v2/events'

          parsed_body = MultiJson.load(last_response.body)
          expect(parsed_body['total_results']).to eq(1)
        end
      end

      context 'as a space auditor' do
        before do
          @space_a.add_auditor(@user_a)
          @space_b.add_auditor(@user_b)
          set_current_user(@user_a)
        end

        it 'includes only events from space visible to the user' do
          get '/v2/events'

          parsed_body = MultiJson.load(last_response.body)
          expect(parsed_body['total_results']).to eq(1)
        end
      end

      context 'as a developer' do
        before do
          @space_a.add_developer(@user_a)
          @space_b.add_developer(@user_b)
          set_current_user(@user_a)
        end

        it 'includes only events from space visible to the user' do
          get '/v2/events'

          parsed_body = MultiJson.load(last_response.body)
          expect(parsed_body['total_results']).to eq(1)
        end
      end

      context 'as a space manager' do
        before do
          @space_a.add_manager(@user_a)
          @space_b.add_manager(@user_b)
          set_current_user(@user_a)
        end

        it 'includes no events' do
          get '/v2/events'

          parsed_body = MultiJson.load(last_response.body)
          expect(parsed_body['total_results']).to eq(0)
        end
      end

      context 'as an admin who likes to delete things' do
        before { set_current_user_as_admin }

        it 'can retrieve events for deleted spaces' do
          get "/v2/events?q=space_guid:#{@space_b.guid}"
          expect(last_response.status).to(eq(200))
          parsed_body = MultiJson.load(last_response.body)
          before_size = parsed_body['total_results']

          delete "/v2/spaces/#{@space_b.guid}"
          expect(last_response.status).to eq(204)

          get "/v2/events?q=space_guid:#{@space_b.guid}"
          expect(last_response.status).to eq(200)
          parsed_body = MultiJson.load(last_response.body)
          after_size = parsed_body['total_results']
          # 1 more event for the deletion.
          expect(after_size).to eq(before_size + 1)

          event = Event.last
          expect(event.type).to eq('audit.space.delete-request')
          expect(event.actee).to eq(@space_b.guid)
        end

        it 'can retrieve events for deleted organizations' do
          get "/v2/events?q=organization_guid:#{@org_a.guid}"
          expect(last_response.status).to(eq(200))
          parsed_body = MultiJson.load(last_response.body)
          before_size = parsed_body['total_results']

          # Have to delete the space as well -- but this adds only one event.
          delete "/v2/organizations/#{@org_a.guid}?recursive=true&async=false"
          expect(last_response.status).to eq(204)

          get "/v2/events?q=organization_guid:#{@org_a.guid}"
          expect(last_response.status).to eq(200)
          parsed_body = MultiJson.load(last_response.body)
          after_size = parsed_body['total_results']
          # 1 more event for the deletion.
          expect(after_size).to eq(before_size + 1)

          event = Event.last
          expect(event.type).to eq('audit.organization.delete-request')
          expect(event.actee).to eq(@org_a.guid)
        end
      end
    end
  end
end
