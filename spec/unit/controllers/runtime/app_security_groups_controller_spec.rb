require "spec_helper"

module VCAP::CloudController
  describe AppSecurityGroupsController do
    let(:group) { AppSecurityGroup.make }

    it_behaves_like "an admin only endpoint", path: "/v2/app_security_groups"

    describe "errors" do
      it "returns AppSecurityGroupInvalid" do
        post '/v2/app_security_groups', '{"name":"one\ntwo"}', json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group is invalid/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupInvalid/)
      end

      it "returns AppSecurityGroupNameTaken errors on unique name errors" do
        AppSecurityGroup.make(name: 'foo')
        post '/v2/app_security_groups', '{"name":"foo"}', json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/name is taken/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupNameTaken/)
      end
    end
  end
end
