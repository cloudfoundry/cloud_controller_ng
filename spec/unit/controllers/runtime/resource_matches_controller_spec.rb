require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::ResourceMatchesController do
    include_context "resource pool"

    before do
      @resource_pool.add_directory(@tmpdir)
    end

    def resource_match_request(verb, path, matches, non_matches)
      user = User.make(:admin => false, :active => true)
      req = MultiJson.dump(matches + non_matches)
      send(verb, path, req, json_headers(headers_for(user)))
      expect(last_response.status).to eq(200)
      resp = MultiJson.load(last_response.body)
      expect(resp).to eq(matches)
    end

    describe "when the app_bits_upload feature flag is enabed" do
      before do
        FeatureFlag.make(name: 'app_bits_upload', enabled: true)
      end

      describe "PUT /v2/resource_match" do
        it "should return an empty list when no resources match" do
          resource_match_request(:put, "/v2/resource_match", [], [@dummy_descriptor])
        end

        it "should return a resource that matches" do
          resource_match_request(:put, "/v2/resource_match", [@descriptors.first], [@dummy_descriptor])
        end

        it "should return many resources that match" do
          resource_match_request(:put, "/v2/resource_match", @descriptors, [@dummy_descriptor])
        end
      end
    end

    describe "when the app_bits_upload feature flag is disabled" do
      before do
        FeatureFlag.make(name: 'app_bits_upload', enabled: false)
      end

      it "allows the upload if the user is an admin" do
        send(:put, "/v2/resource_match", "[]", admin_headers)
        expect(last_response.status).to eq(200)
      end

      it "returns FeatureDisabled unless the user is an admin" do
        user = User.make(:admin => false, :active => true)
        send(:put, "/v2/resource_match", "[]", json_headers(headers_for(user)))
        expect(last_response.status).to eq(403)
        expect(decoded_response["error_code"]).to match(/FeatureDisabled/)
        expect(decoded_response["description"]).to match(/Feature Disabled/)
      end
    end
  end
end
