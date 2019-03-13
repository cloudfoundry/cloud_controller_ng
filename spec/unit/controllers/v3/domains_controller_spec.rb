require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe DomainsController, type: :controller do
  let(:user) { FactoryBot.create(:user) }
  let(:space) { FactoryBot.create(:space) }
  let(:org) { space.organization }

  describe '#index' do
    before do
      VCAP::CloudController::Domain.dataset.destroy
    end

    describe 'for no logged in user' do
      it 'returns 401 for Unauthenticated requests' do
        get :index
        expect(response.status).to eq(401)
      end
    end

    describe 'for a valid user' do
      let!(:private_domain1) { VCAP::CloudController::Domain.make(guid: 'org-private_domain1', owning_organization: org) }
      let!(:public_domain2) { VCAP::CloudController::Domain.make(guid: 'shared-public_domain2') }
      let(:expected_guids) do
        Hash.new([private_domain1.guid, public_domain2.guid]).tap do |h|
          h['org_billing_manager'] = [public_domain2.guid]
        end
      end

      describe 'authorization' do
        roles_to_expected_http_response = {
          'admin' => 200,
          'admin_read_only' => 200,
          'global_auditor' => 200,
          'space_developer' => 200,
          'space_manager' => 200,
          'space_auditor' => 200,
          'org_manager' => 200,
          'org_auditor' => 200,
          'org_billing_manager' => 200,
        }.freeze
        roles_to_expected_http_response.each do |role, expected_return_value|
          context "as a #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(
                role: role,
                org: org,
                space: space,
                user: user,
                scopes: %w(cloud_controller.read cloud_controller.write)
              )
              get :index

              expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
              response_guids = parsed_body['resources'].map { |r| r['guid'] }
              expect(response_guids).to match_array(expected_guids[role]), "expected #{expected_guids[role]}, got #{response_guids} for role #{role}"
            end
          end
        end

        it 'handles the org billing manager correctly' do
          set_current_user_as_role(
            role: 'org_billing_manager',
            org: org,
            space: space,
            user: user,
            scopes: %w(cloud_controller.read cloud_controller.write)
          )
          get :index
          expect(response.status).to eq(200)
          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([public_domain2.guid])
        end
      end

      it 'handles the space manager correctly' do
        set_current_user_as_role(
          role: 'space_manager',
          org: org,
          space: space,
          user: user,
          scopes: %w(cloud_controller.read cloud_controller.write)
        )
        get :index
        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([private_domain1.guid, public_domain2.guid])
      end
    end
  end

  describe '#create' do
    let(:request_body) do
      {
        "name": 'my-domain.biz',
        "internal": true
      }
    end

    describe 'for a valid user' do
      before do
        set_current_user_as_role(role: 'admin', user: user)
      end

      it 'returns a 201' do
        post :create, params: request_body, as: :json

        expect(response.status).to eq(201)

        created_domain = VCAP::CloudController::Domain.last
        expect(created_domain.name).to eq('my-domain.biz')
        expect(created_domain.internal).to be_truthy

        expect(parsed_body['guid']).to eq(created_domain.guid)
        expect(parsed_body['name']).to eq(created_domain.name)
        expect(parsed_body['internal']).to eq(created_domain.internal)
      end

      describe 'validations' do
        context 'when the request is invalid' do
          let(:request_body) do
            {
              "name": 'my-domain.biz',
              "internal": 8,
            }
          end

          it 'returns an error' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq(422)

            expect(parsed_body['errors'][0]['detail']).to eq('Internal must be a boolean')
          end
        end

        context 'when creating the domain returns an error' do
          let(:request_body) do
            {
              "name": 'my-domain.biz',
            }
          end

          before do
            expected_error = VCAP::CloudController::DomainCreate::Error.new('Banana')
            allow_any_instance_of(VCAP::CloudController::DomainCreate).to receive(:create).and_raise(expected_error)
          end

          it 'returns the error' do
            post :create, params: request_body, as: :json

            expect(response.status).to eq(422)

            expect(parsed_body['errors'][0]['detail']).to eq('Banana')
          end
        end
      end
    end

    it_behaves_like 'permissions endpoint' do
      let(:roles_to_http_responses) do
        {
          'admin' => 201,
          'admin_read_only' => 403,
          'global_auditor' => 403,
          'space_developer' => 403,
          'space_manager' => 403,
          'space_auditor' => 403,
          'org_manager' => 403,
          'org_auditor' => 403,
          'org_billing_manager' => 403,
        }
      end
      let(:api_call) { lambda { post :create, params: request_body, as: :json } }
    end

    it 'returns 401 for Unauthenticated requests' do
      post :create, params: request_body, as: :json
      expect(response.status).to eq(401)
    end
  end
end

__END__

TODO: Keep this for writing new list-domain tests
      let(:space1) { Space.make(guid: 'space1', org: org1 )}
      let(:space2) { Space.make(guid: 'space2', org: org2 )}
      let(:space3) { Space.make(guid: 'space3', org: org2 )}
      let(:public_domain1) { SharedDomain.make(guid: 'public_domain1') }
      let(:public_domain2) { SharedDomain.make(guid: 'public_domain2') }
      let(:private_domain1) { PrivateDomain.make(guid: 'private_domain1', owning_organization: org1)}
      let(:private_domain2) { PrivateDomain.make(guid: 'private_domain2', owning_organization: org1)}
      let(:admin_user){ User.make }
      let(:user1){ User.make }
      let(:billing_manager1){ User.make }
      let(:user2){ User.make }
      let(:user3){ User.make }
      let(:logged_out_user){ User.make }
      let(:billing_manager3){ User.make }
      before do
        # org.add_user(admin_user)
        org1.add_user(user1)
        org2.add_user(user2)
        org3.add_user(user3)
        org1.add_billing_manager(billing_manager1)
        org3.add_billing_manager(billing_manager3)
      end
