require "spec_helper"

module VCAP::CloudController
  describe PrivateDomainsController do

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          name: {type: "string", required: true},
          owning_organization_guid: {type: "string", required: true}
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: {type: "string"},
          owning_organization_guid: {type: "string"}
        })
      end
    end

    describe "Creating" do
      let(:owning_org) { Organization.make }
      let(:request_body) do
        MultiJson.dump({ name: "blah.com", owning_organization_guid: owning_org.guid })
      end
      let(:user) { User.make }

      before do
        owning_org.add_manager(user)
      end

      context "when private_domain_creation feature_flag is disabled" do
        before do
          FeatureFlag.make(name: "private_domain_creation", enabled: false)
        end

        it "returns FeatureDisabled" do
          post "/v2/private_domains", request_body, headers_for(user)

          expect(last_response.status).to eq(412)
          expect(decoded_response["error_code"]).to match(/FeatureDisabled/)
          expect(decoded_response["description"]).to match(/Feature Disabled/)
        end

        context "when the user is an admin" do
          it "works normally" do
            post "/v2/private_domains", request_body, admin_headers

            expect(last_response.status).to eq(201)
          end
        end
      end

      context "when private_domain_creation feature_flag is enabled" do
        before do
          FeatureFlag.make(name: "private_domain_creation", enabled: true)
        end

        it "works normally" do
          post "/v2/private_domains", request_body, headers_for(user)

          expect(last_response.status).to eq(201)
        end
      end
    end
  end
end
