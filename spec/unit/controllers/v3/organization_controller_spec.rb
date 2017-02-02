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
  end
end
