require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe DomainsController, type: :controller do
  let(:user) { VCAP::CloudController::User.make }
  let(:space) { VCAP::CloudController::Space.make }
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

    describe 'permissions' do
      context 'when creating an unscoped domain' do
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
      end

      context 'when creating a scoped domain' do
        it_behaves_like 'permissions endpoint' do
          let(:roles_to_http_responses) do
            {
              'admin' => 201,
              'admin_read_only' => 403,
              'global_auditor' => 403,
              'space_developer' => 403,
              'space_manager' => 403,
              'space_auditor' => 403,
              'org_manager' => 201,
              'org_auditor' => 403,
              'org_billing_manager' => 403,
            }
          end

          let(:request_body) do
            {
              "name": 'my-domain.biz',
              "relationships": {
                "organization": {
                  "data": {
                    "guid": org.guid
                  }
                }
              }
            }
          end
          let(:api_call) { lambda { post :create, params: request_body, as: :json } }
        end

        context "when org manager can't write to the org" do
          let(:space1) { VCAP::CloudController::Space.make }
          let(:org1) { space1.organization }
          before do
            set_current_user_as_role(role: 'org_manager', org: org, user: user)
          end
          let(:request_body) do
            {
              "name": 'my-domain.biz',
              "relationships": {
                "organization": {
                  "data": {
                    "guid": org1.guid
                  }
                }
              }
            }
          end

          it 'errors' do
            post :create, params: request_body, as: :json
            expect(response.status).to eq(422)
            expect(parsed_body['errors'][0]['detail']).to eq("Organization with guid '#{org1.guid}' does not exist or you do not have access to it.")
          end
        end

        context "when org does not exist" do
          let(:space1) { VCAP::CloudController::Space.make }
          let(:org1) { space1.organization }
          before do
            set_current_user_as_role(role: 'org_manager', org: org, user: user)
          end
          let(:request_body) do
            {
              "name": 'my-domain.biz',
              "relationships": {
                "organization": {
                  "data": {
                    "guid": "NonExistentOrg"
                  }
                }
              }
            }
          end

          it 'errors' do
            post :create, params: request_body, as: :json
            expect(response.status).to eq(422)
            expect(parsed_body['errors'][0]['detail']).to eq("Organization with guid 'NonExistentOrg' does not exist or you do not have access to it.")
          end
        end

        context "when private_domain_creation feature flag is disabled" do
          context "when user is  an admin" do
           before do
             set_current_user_as_role(role: 'admin', org: org, user: user)
             VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
           end

           let(:request_body) do
             {
               "name": 'my-domain.biz',
               "relationships": {
                 "organization": {
                   "data": {
                     "guid": org.guid
                   }
                 }
               }
             }
           end

           it 'returns 201 created' do
             post :create, params: request_body, as: :json

             expect(response.status).to eq(201)
           end
          end
          context "when user is not an admin" do
            before do
              set_current_user_as_role(role: 'org_manager', org: org, user: user)
              VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false, error_message: nil)
            end

            let(:request_body) do
              {
                "name": 'my-domain.biz',
                "relationships": {
                  "organization": {
                    "data": {
                      "guid": org.guid
                    }
                  }
                }
              }
            end

            it 'raises 403' do
              post :create, params: request_body, as: :json

              expect(response.status).to eq(403)
              expect(parsed_body['errors'][0]['detail']).to eq('Feature Disabled: private_domain_creation')
            end
          end

        end

        context "when org is suspended" do
          let(:org1) { VCAP::CloudController::Organization.make }
          context "when user is an admin" do
            before do
              set_current_user_as_role(role: 'admin', org: org1, user: user)
              org1.status = 'suspended'
              org1.save
            end

            let(:request_body) do
              {
                "name": 'my-domain.biz',
                "relationships": {
                  "organization": {
                    "data": {
                      "guid": org1.guid
                    }
                  }
                }
              }
            end

            it 'returns 201 created' do
              post :create, params: request_body, as: :json

              expect(response.status).to eq(201)
            end
          end

          context "when user is not an admin" do
            before do
              set_current_user_as_role(role: 'org_manager', org: org1, user: user)
              org1.status = 'suspended'
              org1.save
            end

            let(:request_body) do
              {
                "name": 'my-domain.biz',
                "relationships": {
                  "organization": {
                    "data": {
                      "guid": org1.guid
                    }
                  }
                }
              }
            end

            it 'raises 422' do
              post :create, params: request_body, as: :json

              expect(response.status).to eq(422)
              expect(parsed_body['errors'][0]['detail']).to eq("Organization with guid '#{org1.guid}' does not exist or you do not have access to it.")
            end
          end

        end


      end

      it 'returns 401 for Unauthenticated requests' do
        post :create, params: request_body, as: :json
        expect(response.status).to eq(401)
      end
    end

  end
end

