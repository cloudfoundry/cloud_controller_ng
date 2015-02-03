require 'spec_helper'

module VCAP::CloudController
  describe ManagedServiceInstancesController, :services do
    describe 'GET', '/v2/managed_service_instances' do
      it 'should be deprecated' do
        get '/v2/managed_service_instances'
        expect(last_response).to be_a_deprecated_response
      end
    end

    describe 'GET', '/v2/managed_service_instances/:guid' do
      it 'should be deprecated' do
        get '/v2/managed_service_instances/abcd'
        expect(last_response).to be_a_deprecated_response
      end

      it 'redirects to /v2/service_instances/:guid' do
        get '/v2/managed_service_instances/abcd'
        expect(last_response).to have_status_code(302)
      end
    end
  end
end
