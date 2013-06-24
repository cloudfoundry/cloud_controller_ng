require "api/spec_helper"

module VCAP::CloudController
  describe ManagedServiceInstance do
    describe 'GET', '/v2/managed_service_instances/:guid' do
      it 'redirects to /v2/service_instances/:guid' do
        get "/v2/managed_service_instances/abcd"
        last_response.status.should == 302
      end
    end
  end
end


