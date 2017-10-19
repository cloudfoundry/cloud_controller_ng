require 'rails_helper'

RSpec.describe ServiceInstancesV3Controller, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make) }

  describe '#share_service_instance' do
    let(:service_instance) { VCAP::CloudController::ServiceInstance.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:target_space2) { VCAP::CloudController::Space.make }
    let(:service_instance_sharing_enabled) { true }
    let(:source_space) { service_instance.space }

    let(:req_body) do
      {
        data: [
          { guid: target_space.guid }
        ]
      }
    end

    before do
      set_current_user_as_admin
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: service_instance_sharing_enabled, error_message: nil)
    end

    it 'shares the service instance to the target space' do
      post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

      expect(response.status).to eq 200
      expect(parsed_body['data'][0]['guid']).to eq(target_space.guid)
      expect(service_instance.shared_spaces).to contain_exactly(target_space)
    end

    it 'shares the service instance to multiple target spaces' do
      req_body[:data] << { guid: target_space2.guid }

      post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

      expect(response.status).to eq 200

      target_space_guids = []
      parsed_body['data'].each do |item|
        target_space_guids << item['guid']
      end
      expect(target_space_guids).to contain_exactly(target_space.guid, target_space2.guid)

      expect(service_instance.shared_spaces).to contain_exactly(target_space, target_space2)
    end

    context 'when the service_instance_sharing feature flag is disabled' do
      let(:service_instance_sharing_enabled) { false }

      it 'should return a 403 HTTP status code' do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

        expect(response.status).to eq(403)
        expect(response.body).to include('FeatureDisabled')
        expect(response.body).to include('service_instance_sharing')
      end
    end

    context 'when the service instance does not exist' do
      it 'returns a 404' do
        post :share_service_instance, service_instance_guid: 'nonexistant-service-instance-guid', body: req_body
        expect(response.status).to eq 404
        expect(response.body).to include('Service instance not found')
      end
    end

    context 'when the target space does not exist' do
      before do
        req_body[:data] = [{ guid: 'nonexistant-space-guid' }]
      end

      it 'returns a 422' do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body
        expect(response.status).to eq 422
        expect(response.body).to include('Unable to share to spaces')
        expect(response.body).to include('nonexistant-space-guid')
      end
    end

    context 'when multiple target spaces do not exist' do
      before do
        req_body[:data] = [
          { guid: 'nonexistant-space-guid' },
          { guid: 'nonexistant-space-guid2' },
          { guid: target_space.guid }
        ]
      end

      it 'does not share to any of the valid spaces and returns a 422' do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body
        expect(response.status).to eq 422
        expect(response.body).to include('Unable to share to spaces')
        expect(response.body).to include('nonexistant-space-guid')
        expect(response.body).to include('nonexistant-space-guid2')
        expect(service_instance.shared_spaces).to_not include(target_space)
      end
    end

    context 'when the service instance has already been shared with the specified space' do
      before do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body
      end

      it 'returns a 200 and leaves the existing share intact' do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

        expect(response.status).to eq 200
        expect(service_instance.shared_spaces).to include(target_space)
      end
    end

    context 'when the request is malformed' do
      let(:req_body) {
        {
          bork: 'some-name',
        }
      }

      it 'returns a 422' do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body
        expect(response.status).to eq 422
      end
    end

    describe 'permissions by role' do
      context 'when the user is a space developer in the source space' do
        before do
          set_current_user_as_role(role: 'space_developer', org: source_space.organization, space: source_space, user: user)
        end

        role_to_expected_http_response = {
          'admin'               => 200,
          'space_developer'     => 200,
          'admin_read_only'     => 403,
          'global_auditor'      => 403,
          'space_manager'       => 403,
          'space_auditor'       => 403,
          'org_manager'         => 403,
          'org_auditor'         => 422,
          'org_billing_manager' => 422,
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "and #{role} in the target space" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: target_space.organization, space: target_space, user: user)

              post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

              expect(response.status).to eq(expected_return_value),
                "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
              if expected_return_value == 200
                expect(parsed_body['data'][0]['guid']).to eq(target_space.guid)
              end
            end
          end
        end
      end

      context 'when the user is a space developer in the target space' do
        before do
          set_current_user_as_role(role: 'space_developer', org: target_space.organization, space: target_space, user: user)
        end

        role_to_expected_http_response = {
          'admin'               => 200,
          'space_developer'     => 200,
          'admin_read_only'     => 403,
          'global_auditor'      => 403,
          'space_manager'       => 403,
          'space_auditor'       => 403,
          'org_manager'         => 403,
          'org_auditor'         => 404,
          'org_billing_manager' => 404,
        }.freeze

        role_to_expected_http_response.each do |role, expected_return_value|
          context "and #{role} in the source space" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: source_space.organization, space: source_space, user: user)

              post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body

              expect(response.status).to eq(expected_return_value),
                "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
              if expected_return_value == 200
                expect(parsed_body['data'][0]['guid']).to eq(target_space.guid)
              end
            end
          end
        end
      end
    end
  end

  describe '#unshare_service_instance' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:source_space) { service_instance.space }
    let(:service_instance_sharing_enabled) { true }

    let(:req_body) do
      {
        data: [
          { guid: target_space.guid }
        ]
      }
    end

    before do
      feature_flag = VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
      set_current_user_as_admin

      post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body
      expect(response.status).to eq 200

      feature_flag.enabled = service_instance_sharing_enabled
      feature_flag.save
    end

    it 'unshares the service instance from the target space' do
      delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid
      expect(response.status).to eq 204
      expect(service_instance.shared_spaces).to be_empty
    end

    context 'service instance does not exist' do
      it 'returns with 404' do
        delete :unshare_service_instance, service_instance_guid: 'not a service instance guid', space_guid: target_space.guid
        expect(response.status).to eq(404)
      end
    end

    context 'target space does not exist' do
      it 'returns 422' do
        delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: 'non-existent-target-space-guid'
        expect(response.status).to eq(422)
        error_message = 'Unable to unshare service instance from space non-existent-target-space-guid. '\
          'Ensure the space exists and the service instance has been shared to this space.'
        expect(response.body).to include(error_message)
      end
    end

    context 'an application in the target space is bound to the service instance' do
      let(:test_app) { VCAP::CloudController::AppModel.make(space: target_space, name: 'manatea') }
      let(:service_binding) do
        VCAP::CloudController::ServiceBinding.make(service_instance: service_instance,
                                                   app: test_app,
                                                   credentials: { 'amelia' => 'apples' })
      end

      it 'returns 204 and unbinds the app in the target space' do
        delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid
        expect(response.status).to eq(204)
        expect(test_app.service_bindings).to be_empty
      end

      context 'and the service broker fails to unbind' do
        before do
          stub_unbind(service_binding, status: 500)
        end

        it 'returns 502 and does not unshare the service' do
          delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid
          expect(response.status).to eq(502)
          expect(response.body).to include('ServiceInstanceUnshareFailed')
          expect(test_app.service_bindings).to_not be_empty
        end
      end
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin'               => 204,
        'space_developer'     => 204,
        'admin_read_only'     => 403,
        'global_auditor'      => 403,
        'space_manager'       => 403,
        'space_auditor'       => 403,
        'org_manager'         => 403,
        'org_auditor'         => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "when the user is a #{role} in the source space" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: source_space.organization, space: source_space, user: user)

            delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid

            expect(response.status).to eq(expected_return_value),
              "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
          end
        end
      end
    end

    context 'when trying to unshare a service instance that has not been shared' do
      let(:target_space2) { VCAP::CloudController::Space.make }

      it 'returns 422' do
        delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space2.guid
        expect(response.status).to eq(422)
        error_message = "Unable to unshare service instance from space #{target_space2.guid}. "\
          'Ensure the space exists and the service instance has been shared to this space.'
        expect(response.body).to include(error_message)
      end
    end

    context 'when there are multiple shares' do
      let(:target_space2) { VCAP::CloudController::Space.make }

      let(:req_body2) do
        {
          data: [
            { guid: target_space2.guid }
          ]
        }
      end

      before do
        post :share_service_instance, service_instance_guid: service_instance.guid, body: req_body2
        expect(response.status).to eq 200
      end

      it 'only deletes the requested share' do
        delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid
        expect(response.status).to eq(204)
        expect(service_instance.shared_spaces).to contain_exactly(target_space2)
      end
    end

    context 'when feature flag is disabled' do
      let(:service_instance_sharing_enabled) { false }

      it 'returns 403' do
        delete :unshare_service_instance, service_instance_guid: service_instance.guid, space_guid: target_space.guid
        expect(response.status).to eq(403)
        expect(response.body).to include('FeatureDisabled')
        expect(response.body).to include('service_instance_sharing')
      end
    end
  end
end
