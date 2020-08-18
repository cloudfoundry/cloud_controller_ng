require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe ServiceInstancesV3Controller, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make) }
  let(:space) { VCAP::CloudController::Space.make(guid: 'space-1-guid') }
  let!(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, name: 'service-instance-1') }

  describe '#unshare_service_instance' do
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }
    let(:target_space) { VCAP::CloudController::Space.make }
    let(:source_space) { service_instance.space }

    before do
      set_current_user_as_admin

      service_instance.add_shared_space(target_space)
      service_instance.reload
    end

    it 'unshares the service instance from the target space' do
      delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
      expect(response.status).to eq 204
      expect(service_instance.shared_spaces).to be_empty
    end

    context 'service instance does not exist' do
      it 'returns with 404' do
        delete :unshare_service_instance, params: { guid: 'not a service instance guid', space_guid: target_space.guid }
        expect(response.status).to eq(404)
      end
    end

    context 'target space does not exist' do
      it 'returns 422' do
        delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: 'non-existent-target-space-guid' }
        expect(response.status).to eq(422)
        error_message = 'Unable to unshare service instance from space non-existent-target-space-guid. '\
          'Ensure the space exists and the service instance has been shared to this space.'
        expect(response.body).to include(error_message)
      end
    end

    context 'an application in the target space is bound to the service instance' do
      let(:test_app) { VCAP::CloudController::AppModel.make(space: target_space, name: 'manatea') }
      let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: test_app, credentials: { 'amelia' => 'apples' }) }

      context 'and the service broker successfully unbinds' do
        before do
          stub_unbind(service_binding, status: 200, accepts_incomplete: true)
        end

        it 'returns 204 and unbinds the app in the target space' do
          delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
          expect(response.status).to eq(204)
          expect(test_app.service_bindings).to be_empty
        end
      end

      context 'and the service broker fails to unbind' do
        before do
          stub_unbind(service_binding, status: 500, accepts_incomplete: true)
        end

        it 'returns 502 and does not unshare the service' do
          delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
          expect(response.status).to eq(502)
          expect(response.body).to include('ServiceInstanceUnshareFailed')
          expect(test_app.service_bindings).to_not be_empty
        end

        it 'returns an error with detailed message' do
          delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
          expect(response.body).to include('The service broker returned an invalid response')
        end
      end

      context 'and the service broker responds asynchronously to unbinds' do
        before do
          stub_unbind(service_binding, status: 202, accepts_incomplete: true)
        end

        it 'returns an error with message that an operation is in progress' do
          delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }

          expect(response.status).to eq(502)
          expect(response.body).to include("The binding between an application and service instance #{service_instance.name}" \
                                           " in space #{target_space.name} is being deleted asynchronously.")
        end
      end
    end

    context 'when the user has access to the service instance through a share' do
      before do
        service_instance.add_shared_space(target_space)
        set_current_user_as_role(role: 'space_developer', org: target_space.organization, space: target_space, user: user)
      end

      it 'cannot unshare the service instance' do
        delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
        expect(response.status).to eq 403
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

            delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }

            expect(response.status).to eq(expected_return_value),
              "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
          end
        end
      end
    end

    context 'when trying to unshare a service instance that has not been shared' do
      let(:target_space2) { VCAP::CloudController::Space.make }

      it 'returns 422' do
        delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space2.guid }
        expect(response.status).to eq(422)
        error_message = "Unable to unshare service instance from space #{target_space2.guid}. "\
          'Ensure the space exists and the service instance has been shared to this space.'
        expect(response.body).to include(error_message)
      end
    end

    context 'when there are multiple shares' do
      let(:target_space2) { VCAP::CloudController::Space.make }

      before do
        service_instance.add_shared_space(target_space2)
        service_instance.reload
      end

      it 'only deletes the requested share' do
        delete :unshare_service_instance, params: { guid: service_instance.guid, space_guid: target_space.guid }
        expect(response.status).to eq(204)
        expect(service_instance.shared_spaces).to contain_exactly(target_space2)
      end
    end
  end
end
