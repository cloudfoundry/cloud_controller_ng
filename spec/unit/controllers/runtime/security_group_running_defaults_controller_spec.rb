require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SecurityGroupRunningDefaultsController do
    before { set_current_user_as_admin }

    it 'returns an error for a regular user' do
      set_current_user(User.make)
      get '/v2/config/running_security_groups'
      expect(last_response.status).to eq(403)
    end

    it 'only returns SecurityGroups that are running defaults' do
      SecurityGroup.make(running_default: false)
      running_default = SecurityGroup.make(running_default: true)

      get '/v2/config/running_security_groups'
      expect(decoded_response['total_results']).to eq(1)
      expect(decoded_response['resources'][0]['metadata']['guid']).to eq(running_default.guid)
    end

    describe 'assigning a security group as a default' do
      it 'should set running_default to true on the security group and return the security group' do
        security_group = SecurityGroup.make(running_default: false)

        put "/v2/config/running_security_groups/#{security_group.guid}", {}

        expect(last_response.status).to eq(200)
        expect(security_group.reload.running_default).to be true
        expect(decoded_response['metadata']['guid']).to eq(security_group.guid)
      end

      it 'should return a 400 when the security group does not exist' do
        put '/v2/config/running_security_groups/bogus', {}
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group could not be found/)
        expect(decoded_response['error_code']).to match(/SecurityGroupRunningDefaultInvalid/)
      end
    end

    context 'removing a security group as a default' do
      it 'should set running_default to false on the security group' do
        security_group = SecurityGroup.make(running_default: true)

        delete "/v2/config/running_security_groups/#{security_group.guid}"

        expect(last_response.status).to eq(204)
        expect(security_group.reload.running_default).to be false
      end

      it 'should return a 400 when the security group does not exist' do
        delete '/v2/config/running_security_groups/bogus'
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group could not be found/)
        expect(decoded_response['error_code']).to match(/SecurityGroupRunningDefaultInvalid/)
      end
    end
  end
end
