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
  end
end
