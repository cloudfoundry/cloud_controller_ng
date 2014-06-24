require "spec_helper"

module VCAP::CloudController
  describe AppSecurityGroupRunningDefaultsController do
    it_behaves_like "an admin only endpoint", path: "/v2/config/running_security_groups"
    context "with app security groups that are running defaults" do
      before do
        8.times { AppSecurityGroup.make(running_default: true) }
      end
    end

    it "only returns AppSecurityGroups that are running defaults" do
      AppSecurityGroup.make(running_default: false)
      running_default = AppSecurityGroup.make(running_default: true)

      get "/v2/config/running_security_groups", {}, admin_headers
      expect(decoded_response["total_results"]).to eq(1)
      expect(decoded_response["resources"][0]["metadata"]["guid"]).to eq(running_default.guid)
    end

    context "assigning an asg as a default" do
      it "should set running_default to true on the asg and return the asg" do
        app_sec_group = AppSecurityGroup.make(running_default: false)

        put "/v2/config/running_security_groups/#{app_sec_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(200)
        expect(app_sec_group.reload.running_default).to be true
        expect(decoded_response["metadata"]["guid"]).to eq(app_sec_group.guid)
      end

      it "should return a 400 when the asg does not exist" do
        put "/v2/config/running_security_groups/bogus", {}, admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group could not be found/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupRunningDefaultInvalid/)
      end
    end

    context "removing an asg as a default" do
      it "should set running_default to false on the asg" do
        app_sec_group = AppSecurityGroup.make(running_default: true)

        delete "/v2/config/running_security_groups/#{app_sec_group.guid}", {}, admin_headers

        expect(last_response.status).to eq(204)
        expect(app_sec_group.reload.running_default).to be false
      end

      it "should return a 400 when the asg does not exist" do
        delete "/v2/config/running_security_groups/bogus", {}, admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['description']).to match(/app security group could not be found/)
        expect(decoded_response['error_code']).to match(/AppSecurityGroupRunningDefaultInvalid/)
      end
    end
  end
end
