require 'spec_helper'

module VCAP::CloudController
  describe SecurityGroupStagingDefaultsController do
    it_behaves_like 'an admin only endpoint', path: '/v2/config/staging_security_groups'

    it 'only returns SecurityGroups that are staging defaults' do
      SecurityGroup.make(staging_default: false)
      staging_default = SecurityGroup.make(staging_default: true)

      get '/v2/config/staging_security_groups', {}, admin_headers
      expect(decoded_response['total_results']).to eq(1)
      expect(decoded_response['resources'][0]['metadata']['guid']).to eq(staging_default.guid)
    end

    context 'assigning a security group as a default' do
      it 'should set staging_default to true on the security group and return the security group' do
        security_group = SecurityGroup.make(staging_default: false)

        put "/v2/config/staging_security_groups/#{security_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(200)
        expect(security_group.reload.staging_default).to be true
        expect(decoded_response['metadata']['guid']).to eq(security_group.guid)
      end

      it 'should return a 400 when the security group does not exist' do
        put '/v2/config/staging_security_groups/bogus', {}, admin_headers

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group could not be found/)
        expect(decoded_response['error_code']).to match(/SecurityGroupStagingDefaultInvalid/)
      end
    end

    context 'removing a security group as a default' do
      it 'should set staging_default to false on the security group' do
        security_group = SecurityGroup.make(staging_default: true)

        delete "/v2/config/staging_security_groups/#{security_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(204)
        expect(security_group.reload.staging_default).to be false
      end

      it 'should return a 400 when the security group does not exist' do
        delete '/v2/config/staging_security_groups/bogus', {}, admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/security group could not be found/)
        expect(decoded_response['error_code']).to match(/SecurityGroupStagingDefaultInvalid/)
      end
    end
  end
end
