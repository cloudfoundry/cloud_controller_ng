require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::RoutesController do

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:host) }
      it { expect(described_class).to be_queryable_by(:domain_guid) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
          host:        { type: "string", default: "" },
          domain_guid: { type: "string", required: true },
          space_guid:  { type: "string", required: true },
          app_guids:   { type: "[string]" }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          host:        { type: "string" },
          domain_guid: { type: "string" },
          space_guid:  { type: "string" },
          app_guids:   { type: "[string]" }
        })
      end
    end

    describe "Permissions" do
      context "with a custom domain" do
        include_context "permissions"

        before do
          @domain_a = PrivateDomain.make(owning_organization: @org_a)
          @obj_a    = Route.make(domain: @domain_a, space: @space_a)

          @domain_b = PrivateDomain.make(owning_organization: @org_b)
          @obj_b    = Route.make(domain: @domain_b, space: @space_b)
        end

        describe "Org Level Permissions" do
          describe "OrgManager" do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples "permission enumeration", "OrgManager",
              name: 'route',
              path: "/v2/routes",
              enumerate: 1
          end

          describe "OrgUser" do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples "permission enumeration", "OrgUser",
              name: 'route',
              path: "/v2/routes",
              enumerate: 0
          end

          describe "BillingManager" do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples "permission enumeration", "BillingManager",
              name: 'route',
              path: "/v2/routes",
              enumerate: 0
          end

          describe "Auditor" do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples "permission enumeration", "Auditor",
              name: 'route',
              path: "/v2/routes",
              enumerate: 1
          end
        end

        describe "App Space Level Permissions" do
          describe "SpaceManager" do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples "permission enumeration", "SpaceManager",
              name: 'route',
              path: "/v2/routes",
              enumerate: 1
          end

          describe "Developer" do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples "permission enumeration", "Developer",
              name: 'route',
              path: "/v2/routes",
              enumerate: 1
          end

          describe "SpaceAuditor" do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples "permission enumeration", "SpaceAuditor",
              name: 'route',
              path: "/v2/routes",
              enumerate: 1
          end
        end
      end
    end

    describe "Validation messages" do
      let(:domain) { SharedDomain.make }
      let(:space) { Space.make }

      it "returns the RouteHostTaken message" do
        taken_host = "someroute"
        Route.make(host: taken_host, domain: domain)

        post "/v2/routes", MultiJson.dump(host: taken_host, domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(210003)
      end

      it "returns the SpaceQuotaTotalRoutesExceeded message" do
        quota_definition = SpaceQuotaDefinition.make(total_routes: 0, organization: space.organization)
        space.space_quota_definition = quota_definition
        space.save

        post "/v2/routes", MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310005)
      end

      it "returns the OrgQuotaTotalRoutesExceeded message" do
        quota_definition = space.organization.quota_definition
        quota_definition.total_routes = 0
        quota_definition.save

        post "/v2/routes", MultiJson.dump(host: 'myexample', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(310006)
      end

      it "returns the RouteInvalid message" do
        post "/v2/routes", MultiJson.dump(host: 'myexample!*', domain_guid: domain.guid, space_guid: space.guid), json_headers(admin_headers)

        expect(last_response.status).to eq(400)
        expect(decoded_response["code"]).to eq(210001)
      end
    end

    describe 'POST /v2/routes' do
      let(:space) {Space.make}
      let(:user) {User.make}
      let(:req) {{
                   domain_guid: SharedDomain.make.guid,
                   space_guid:  space.guid,
                   host:        'example'
      }}

      before do
        space.organization.add_user(user)
        space.add_developer(user)
      end

      context 'when route_creation feature flag is disabled' do
        before { FeatureFlag.make(name: 'route_creation', enabled: false, error_message: nil) }

        it 'returns FeatureDisabled for users' do
          post '/v2/routes', MultiJson.dump(req), headers_for(user)

          expect(last_response.status).to eq(403)
          expect(decoded_response['error_code']).to match(/FeatureDisabled/)
          expect(decoded_response['description']).to match(/route_creation/)
        end
      end
    end
  end
end
