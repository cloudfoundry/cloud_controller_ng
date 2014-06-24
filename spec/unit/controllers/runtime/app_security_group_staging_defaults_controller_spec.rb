require "spec_helper"

module VCAP::CloudController
  describe AppSecurityGroupStagingDefaultsController do
    it_behaves_like "an admin only endpoint", path: "/v2/config/staging_security_groups"
    context "with app security groups that are staging defaults" do
      before do
        8.times { AppSecurityGroup.make(staging_default: true) }
      end
    end

    it "only returns AppSecurityGroups that are staging defaults" do
      AppSecurityGroup.make(staging_default: false)
      staging_default = AppSecurityGroup.make(staging_default: true)

      get "/v2/config/staging_security_groups", {}, admin_headers
      expect(decoded_response["total_results"]).to eq(1)
      expect(decoded_response["resources"][0]["metadata"]["guid"]).to eq(staging_default.guid)
    end

    context "assigning an asg as a default" do
      it "should set staging_default to true on the asg and return the asg" do
        app_sec_group = AppSecurityGroup.make(staging_default: false)

        put "/v2/config/staging_security_groups/#{app_sec_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(200)
        expect(app_sec_group.reload.staging_default).to be true
        expect(decoded_response["metadata"]["guid"]).to eq(app_sec_group.guid)
      end

      it "should return a 400 when the asg does not exist" do
        put "/v2/config/staging_security_groups/bogus", {}, admin_headers

        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group could not be found/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupStagingDefaultInvalid/)
      end
    end

    context "removing an asg as a default" do
      it "should set staging_default to false on the asg" do
        app_sec_group = AppSecurityGroup.make(staging_default: true)

        delete "/v2/config/staging_security_groups/#{app_sec_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(204)
        expect(app_sec_group.reload.staging_default).to be false
      end

      it "should return a 400 when the asg does not exist" do
        delete "/v2/config/staging_security_groups/bogus", {}, admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group could not be found/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupStagingDefaultInvalid/)
      end
    end
  end
end
