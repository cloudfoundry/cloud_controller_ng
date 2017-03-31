require 'rails_helper'

RSpec.describe SpacesV3Controller, type: :controller do
  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org1) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:org2) { VCAP::CloudController::Organization.make(name: 'Greg\'s Ranch') }
    let!(:manager_space) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org1) }
    let!(:developer_space) { VCAP::CloudController::Space.make(name: 'Alpaca', organization: org1) }
    let!(:auditor_space) { VCAP::CloudController::Space.make(name: 'Horse', organization: org2) }
    let!(:other_space) { VCAP::CloudController::Space.make(name: 'Buffalo') }

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      it 'returns a 200 and all spaces' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
          'Lamb', 'Alpaca', 'Horse', 'Buffalo'
        ])
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
          expect(parsed_response['resources'][0]['name']).to eq('Alpaca')
        end
      end

      context 'when invalid pagination values are specified' do
        it 'returns 400' do
          get :index, per_page: 'meow'

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'when unknown pagination fields are specified' do
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

    context 'when the user is an org manager in an org containing spaces' do
      before do
        org1.add_manager(user)
      end

      it 'they see all spaces in the org' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
          'Lamb', 'Alpaca',
        ])
      end
    end

    context 'when the user has another org role' do
      before do
        org1.add_auditor(user)
      end

      it 'they see all spaces in the org' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].length).to eq(0)
      end
    end

    context 'when the user has no special global or org role' do
      before do
        org1.add_user(user)
        org2.add_user(user)
        manager_space.add_manager(user)
        developer_space.add_developer(user)
        auditor_space.add_auditor(user)
      end

      it 'returns all spaces they are a developer or manager' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
          manager_space.name, developer_space.name, auditor_space.name,
        ])
      end
    end

    describe 'filters' do
      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        describe 'names' do
          it 'returns the list of matching spaces' do
            get :index, { names: 'Alpaca,Horse' }

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
              'Alpaca', 'Horse',
            ])
          end
        end
      end

      context 'when the user does NOT have global read access' do
        before do
          org1.add_manager(user)
        end

        describe 'names' do
          it 'returns the list of matching spaces' do
            get :index, { names: 'Alpaca,Horse' }

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
              'Alpaca',
            ])
          end
        end
      end
    end
  end

  describe '#update_isolation_segment' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org1) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:org2) { VCAP::CloudController::Organization.make(name: 'Greg\'s Ranch') }
    let!(:space1) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org1) }
    let!(:space2) { VCAP::CloudController::Space.make(name: 'Alpaca', organization: org1) }
    let!(:space3) { VCAP::CloudController::Space.make(name: 'Horse', organization: org2) }
    let!(:space4) { VCAP::CloudController::Space.make(name: 'Buffalo') }
    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let!(:update_message) { { 'data' => { 'guid' => isolation_segment_model.guid } } }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the org has been entitled with the isolation segment' do
        before do
          assigner.assign(isolation_segment_model, [org1])
        end

        it 'can assign an isolation segment to a space in org1' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(200)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(isolation_segment_model.guid)
          expect(parsed_body['data']['guid']).to eq(isolation_segment_model.guid)
          expect(parsed_body['links']['self']['href']).to include("v3/spaces/#{space1.guid}/relationships/isolation_segment")
        end

        it 'can remove an isolation segment from a space' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(200)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(isolation_segment_model.guid)

          patch :update_isolation_segment, guid: space1.guid, body: { data: nil }
          expect(response.status).to eq(200)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(nil)
          expect(parsed_body['links']['self']['href']).to include("v3/spaces/#{space1.guid}/relationships/isolation_segment")
        end
      end

      context 'when the org has not been entitled with the isolation segment' do
        it 'will not assign an isolation segment to a space in a different org' do
          patch :update_isolation_segment, guid: space3.guid, body: update_message

          expect(response.status).to eq(422)
          expect(response.body).to include(
            "Unable to assign isolation segment with guid '#{isolation_segment_model.guid}'. Ensure it has been entitled to the organization that this space belongs to."
          )
        end
      end

      context 'when the isolation segment cannot be found' do
        let!(:update_message) { { 'data' => { 'guid' => 'potato' } } }

        it 'raises an error' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(422)
          expect(response.body).to include(
            "Unable to assign isolation segment with guid 'potato'. Ensure it has been entitled to the organization that this space belongs to."
          )
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have permissions to read from the space' do
        before do
          allow_user_read_access_for(user, orgs: [], spaces: [])
        end

        it 'throws ResourceNotFound error' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Space not found'
        end
      end

      context 'when the user is an org manager' do
        before do
          assigner.assign(isolation_segment_model, [org1])
          org1.add_manager(user)
        end

        it 'returns a successful response' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(200)
        end
      end

      context 'when the user is not an org manager' do
        before do
          allow_user_read_access_for(user, orgs: [org1], spaces: [space1])
        end

        it 'returns an Unauthorized error' do
          patch :update_isolation_segment, guid: space1.guid, body: update_message

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#show_isolation_segment' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:space) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org) }
    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    context 'when the user has permissions to read from the space' do
      before do
        allow_user_read_access_for(user, orgs: [org], spaces: [space])
        assigner.assign(isolation_segment_model, [org])
        space.update(isolation_segment_guid: isolation_segment_model.guid)
      end

      it 'returns a 200 and the isolation segment associated with the space' do
        get :show_isolation_segment, guid: space.guid

        expect(response.status).to eq(200)
        expect(parsed_body['data']['guid']).to eq(isolation_segment_model.guid)
      end

      context 'when the space does not exist' do
        it 'returns a 404' do
          get :show_isolation_segment, guid: 'potato'

          expect(response.status).to eq(404)
          expect(response.body).to include('Space not found')
        end
      end

      context 'when the space is not associated with an isolation segment' do
        before { space.update(isolation_segment_guid: nil) }

        it 'returns a 200' do
          get :show_isolation_segment, guid: space.guid

          expect(response.status).to eq(200)
          expect(parsed_body['data']).to eq(nil)
        end
      end
    end

    context 'when the user does not have permissions to read from the space' do
      before { allow_user_read_access_for(user, orgs: [], spaces: []) }

      it 'throws ResourceNotFound error' do
        get :show_isolation_segment, guid: space.guid

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Space not found'
      end
    end
  end
end
