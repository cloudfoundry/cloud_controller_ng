require "spec_helper"

module VCAP::CloudController
  describe ManagedServiceInstancesController, :services do
    describe 'GET', '/v2/managed_service_instances/:guid' do
      it 'redirects to /v2/service_instances/:guid' do
        get "/v2/managed_service_instances/abcd"
        expect(last_response.status).to eq(302)
      end
    end
  end
end


