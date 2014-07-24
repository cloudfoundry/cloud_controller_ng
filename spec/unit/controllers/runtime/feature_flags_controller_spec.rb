require "spec_helper"

module VCAP::CloudController
  describe FeatureFlagsController, type: :controller do
    it_behaves_like "an admin only endpoint", path: "/v2/config/feature_flags"

    describe "setting a feature flag" do
      context "when the user is an admin" do
        it "should set the feature flag to the specified value" do
          feature_flag = FeatureFlag.make(enabled: false, name: "foobar")

          put "/v2/config/feature_flags/#{feature_flag.name}", MultiJson.dump({enabled: true}), admin_headers

          expect(last_response.status).to eq(200)
          expect(feature_flag.reload.enabled).to be true
        end

        it "should return a 404 when the feature flag does not exist" do
          put "/v2/config/feature_flags/bogus", {}, admin_headers
          expect(last_response.status).to eq(404)
          expect(decoded_response['description']).to match(/feature flag could not be found/)
          expect(decoded_response['error_code']).to match(/FeatureFlagNotFound/)
        end
      end

      context "when the user is not an admin" do
        it "should return a 403" do
          feature_flag = FeatureFlag.make(enabled: false, name: "foobar")

          put "/v2/config/feature_flags/#{feature_flag.name}", MultiJson.dump({enabled: true}), headers_for(User.make)

          expect(last_response.status).to eq(403)
          expect(decoded_response['description']).to match(/not authorized/)
          expect(decoded_response['error_code']).to match(/NotAuthorized/)
        end
      end
    end
  end
end
