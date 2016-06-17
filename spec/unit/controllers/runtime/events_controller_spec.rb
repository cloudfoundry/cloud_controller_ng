require 'spec_helper'

module VCAP::CloudController
  RSpec.describe EventsController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:timestamp) }
      it { expect(described_class).to be_queryable_by(:type) }
      it { expect(described_class).to be_queryable_by(:actee) }
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
          @space_a.organization.add_auditor(@user_a)
          set_current_user(@user_a)
        end

        it 'includes only events from space visible to the user' do
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
    end
  end
end
