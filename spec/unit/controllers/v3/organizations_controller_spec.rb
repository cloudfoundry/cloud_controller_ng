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
end
