require 'rails_helper'

RSpec.describe OrganizationsV3Controller, type: :controller do
  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:member_org) { VCAP::CloudController::Organization.make(name: 'Marmot') }
    let!(:manager_org) { VCAP::CloudController::Organization.make(name: 'Rat') }
    let!(:billing_manager_org) { VCAP::CloudController::Organization.make(name: 'Beaver') }
    let!(:auditor_org) { VCAP::CloudController::Organization.make(name: 'Capybara') }
    let!(:other_org) { VCAP::CloudController::Organization.make(name: 'Groundhog') }

    before do
      member_org.add_user(user)
      manager_org.add_manager(user)
      billing_manager_org.add_billing_manager(user)
      auditor_org.add_auditor(user)
    end

    it 'returns orgs the user has read access' do
      get :index

      expect(response.status).to eq(200)
      expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
        member_org.name, manager_org.name, billing_manager_org.name, auditor_org.name
      ])
    end

    describe 'query params' do
      describe 'names' do
        it 'returns orgs with matching names' do
          get :index, names: 'Marmot,Beaver'

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
            'Marmot', 'Beaver'
          ])
        end
      end
    end

    describe 'query params errors' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, per_page: 'meow'

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, meow: 'bad-val', nyan: 'mow'

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 2 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params

        parsed_response = parsed_body
        expect(parsed_response['pagination']['total_results']).to eq(4)
        expect(parsed_response['resources'].length).to eq(per_page)
        expect(parsed_response['resources'][0]['name']).to eq('Rat')
      end
    end

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      it 'returns a 200 and all organizations' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].length).to eq(6)
      end
    end

    context 'when accessed as an isolation segment subresource' do
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
      let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:org1) { VCAP::CloudController::Organization.make }
      let(:org2) { VCAP::CloudController::Organization.make }
      let(:org3) { VCAP::CloudController::Organization.make }

      before do
        VCAP::CloudController::Organization.make
        assigner.assign(isolation_segment_model, [org1, org2])
        org1.add_user(user)
        org2.add_user(user)
        org3.add_user(user)
      end

      it 'uses the isolation_segment as a filter' do
        get :index, isolation_segment_guid: isolation_segment_model.guid

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([org1.guid, org2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, isolation_segment_guid: isolation_segment_model.guid
        expect(response.status).to eq(200)
        expect(parsed_body['pagination']['first']['href']).to include("/v3/isolation_segments/#{isolation_segment_model.guid}/organizations")
      end

      context 'when pagination options are specified' do
        let(:page) { 1 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page, isolation_segment_guid: isolation_segment_model.guid } }

        it 'paginates the response' do
          get :index, params

          parsed_response = parsed_body
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(response_guids.length).to eq(per_page)
        end
      end

      context 'the isolation_segment does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, isolation_segment_guid: 'not-an-iso-seg'

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the isolation_segment' do
        before do
          org1.remove_user(user)
          org2.remove_user(user)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, isolation_segment_guid: isolation_segment_model.guid

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when the isolation segment organizations contains organizations the user cannot see' do
        let(:org4) { VCAP::CloudController::Organization.make }

        before do
          assigner.assign(isolation_segment_model, [org4])
        end

        it 'only displays to me the organizations that the user can see' do
          get :index, isolation_segment_guid: isolation_segment_model.guid

          expect(response.status).to eq 200
          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([org1.guid, org2.guid])
        end
      end
    end
  end

  describe '#show_default_isolation_segment' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
    let(:unassigner) { VCAP::CloudController::IsolationSegmentUnassign.new }

    before do
      assigner.assign(isolation_segment, [org])
      org.update(default_isolation_segment_guid: isolation_segment.guid)
    end

    context 'with sufficient permissions' do
      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [org])
      end

      it 'presents the default isolation segment' do
        get :show_default_isolation_segment, guid: org.guid

        expect(response.status).to eq(200)
        expect(parsed_body['data']['guid']).to eq(isolation_segment.guid)
      end

      context 'when the organization does not exist' do
        it 'throws ResourceNotFound error' do
          get :show_default_isolation_segment, guid: 'cest-ne-pas-un-org'

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end

      context 'when there is no default isolation segment' do
        before do
          org.update(default_isolation_segment_guid: nil)
        end

        it 'presents a null guid' do
          get :show_default_isolation_segment, guid: org.guid

          expect(response.status).to eq(200)
          expect(parsed_body['data']).to eq(nil)
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have cloud_controller.read' do
        before do
          set_current_user(user, scopes: ['cloud_controller.write'])
        end

        it 'throws a NotAuthorized error' do
          get :show_default_isolation_segment, guid: org.guid

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have permissions to read from organization' do
        before do
          set_current_user(user)
          allow_user_read_access_for(user)
        end

        it 'throws ResourceNotFound error' do
          get :show_default_isolation_segment, guid: org.guid

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end
    end
  end

  describe '#update_default_isolation_segment' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
    let(:unassigner) { VCAP::CloudController::IsolationSegmentUnassign.new }
    let(:req_body) do
      {
        data: { guid: isolation_segment.guid }
      }.to_json
    end

    before do
      set_current_user(user, { admin: true })
      allow_user_read_access_for(user, orgs: [org])
      assigner.assign(isolation_segment, [org])
    end

    it 'updates the organization' do
      expect(org.default_isolation_segment_guid).to eq(nil)

      patch :update_default_isolation_segment, req_body, { guid: org.guid }

      org.reload
      expect(response.status).to eq(200)
      expect(org.default_isolation_segment_guid).to eq(isolation_segment.guid)
      expect(parsed_body['data']['guid']).to eq(isolation_segment.guid)
    end

    context 'when the requested data is null' do
      let(:req_body) do
        {
          data: nil
        }.to_json
      end

      before do
        org.default_isolation_segment_guid = 'prev-iso-seg'
      end
      it 'should update the org default iso seg guid to null' do
        expect(org.default_isolation_segment_guid).to eq('prev-iso-seg')

        patch :update_default_isolation_segment, req_body, { guid: org.guid }

        org.reload
        expect(response.status).to eq(200)
        expect(org.default_isolation_segment_guid).to be_nil
        expect(parsed_body['data']).to be_nil
      end
    end

    context 'when the requested isolation segment has not been entitled to the org' do
      let(:org2) { VCAP::CloudController::Organization.make }
      before do
        allow_user_read_access_for(user, orgs: [org2])
      end

      it 'throws an UnprocessableEntity error ' do
        patch :update_default_isolation_segment, req_body, { guid: org2.guid }

        org.reload
        error_string = "Unable to assign isolation segment with guid '#{isolation_segment.guid}'. Ensure it has been entitled to the organization."

        expect(response.status).to eq(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include(error_string)
      end
    end

    context 'when the organization does not exist' do
      it 'throws ResourceNotFound error' do
        patch :update_default_isolation_segment, req_body, { guid: 'cest-ne-pas-un-org' }

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Organization not found'
      end
    end

    context 'when the isolation segment does not exist' do
      let(:req_body) do
        {
          data: { guid: 'garbage-guid' }
        }.to_json
      end

      it 'throws UnprocessableEntity error' do
        patch :update_default_isolation_segment, req_body, { guid: org.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unable to assign isolation segment with guid 'garbage-guid'. Ensure it has been entitled to the organization."
      end
    end

    context 'when the assignment fails' do
      before do
        allow_any_instance_of(VCAP::CloudController::SetDefaultIsolationSegment).to receive(:set).and_raise(
          VCAP::CloudController::SetDefaultIsolationSegment::Error.new('bad thing happened!'))
      end

      it 'returns 422' do
        patch :update_default_isolation_segment, req_body, { guid: org.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('bad thing happened!')
      end
    end

    context 'when the request provides invalid data' do
      let(:req_body) do
        {
          data: { guid: 123 }
        }.to_json
      end

      it 'returns 422' do
        patch :update_default_isolation_segment, req_body, { guid: org.guid }

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('123 must be a string')
      end
    end

    context 'permissions' do
      context 'when the user does not have permissions to read from organization' do
        before do
          allow_user_read_access_for(user)
        end

        it 'throws ResourceNotFound error' do
          patch :update_default_isolation_segment, req_body, { guid: org.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end

      context 'when the user is not an admin or org manager for that org' do
        before do
          allow_user_read_access_for(user, orgs: [org])
          set_current_user(user, { admin: false })
        end

        it 'throws Unauthorized error' do
          patch :update_default_isolation_segment, req_body, { guid: org.guid }

          expect(org.managers).not_to include(user)
          expect(user.admin).to be_falsey
          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end
end
