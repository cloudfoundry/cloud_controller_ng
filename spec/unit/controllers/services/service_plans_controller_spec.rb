require "spec_helper"

module VCAP::CloudController
  describe ServicePlansController, :services do
    shared_examples "enumerate and read plan only" do |perm_name|
      include_examples "permission enumeration", perm_name,
        :name => 'service plan',
        :path => "/v2/service_plans",
        :permissions_overlap => true,
        :enumerate => 7
    end

    describe "Query Parameters" do
      it { expect(described_class).to be_queryable_by(:active) }
      it { expect(described_class).to be_queryable_by(:service_guid) }
      it { expect(described_class).to be_queryable_by(:service_instance_guid) }
    end

    describe "Attributes" do
      it do
        expect(described_class).to have_creatable_attributes({
                                                               name: {type: "string", required: true},
                                                               free: {type: "bool", required: true},
                                                               description: {type: "string", required: true},
                                                               extra: {type: "string"},
                                                               unique_id: {type: "string"},
                                                               public: {type: "bool", default: true},
                                                               service_guid: {type: "string", required: true},
                                                               service_instance_guids: {type: "[string]"}
                                                             })

      end

      it do
        expect(described_class).to have_updatable_attributes({
                                                               name: {type: "string"},
                                                               free: {type: "bool"},
                                                               description: {type: "string"},
                                                               extra: {type: "string"},
                                                               unique_id: {type: "string"},
                                                               public: {type: "bool"},
                                                               service_guid: {type: "string"},
                                                               service_instance_guids: {type: "[string]"}
                                                             })

      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        5.times { ServicePlan.make }
        @obj_a = ServicePlan.make
        @obj_b = ServicePlan.make
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "enumerate and read plan only", "OrgManager"
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "enumerate and read plan only", "OrgUser"
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "enumerate and read plan only", "BillingManager"
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "enumerate and read plan only", "Auditor"
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "enumerate and read plan only", "SpaceManager"
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "enumerate and read plan only", "Developer"
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "enumerate and read plan only", "SpaceAuditor"
        end
      end
    end

    let(:developer) { make_developer_for_space(Space.make) }

    describe "modifying service plans" do
      let!(:plan) { ServicePlan.make }
      let(:body) { Yajl::Encoder.encode("public" => false) }

      context "a cf admin" do
        it "can modify service plans" do
          put "/v2/service_plans/#{plan.guid}", body, json_headers(admin_headers)
          expect(last_response.status).to eq(201)
          expect(plan.reload.public).to be false
        end
      end

      context "otherwise" do
        it "cannot modify service plans" do
          put "/v2/service_plans/#{plan.guid}", body, json_headers(headers_for(developer))
          expect(last_response.status).to eq(403)
          expect(plan.reload.public).to be true
        end
      end
    end

    describe "non public service plans" do
      let!(:private_plan) { ServicePlan.make(public: false) }

      let(:plan_guids) do
        decoded_response.fetch('resources').collect do |r|
          r.fetch('metadata').fetch('guid')
        end
      end

      it "is not visible to users from normal organization" do
        get '/v2/service_plans', {}, headers_for(developer)
        expect(plan_guids).not_to include(private_plan.guid)
      end

      it "is visible to users from organizations with access to the plan" do
        organization = developer.organizations.first
        VCAP::CloudController::ServicePlanVisibility.create(
          organization: organization,
          service_plan: private_plan,
        )
        get '/v2/service_plans', {}, headers_for(developer)
        expect(plan_guids).to include(private_plan.guid)
      end

      it "is visible to cf admin" do
        get '/v2/service_plans', {}, admin_headers
        expect(plan_guids).to include(private_plan.guid)
      end
    end

    describe "public service plans" do
      let!(:public_plan) { ServicePlan.make(public: true) }

      it "should return correct visibility" do
        get "/v2/service_plans/#{public_plan.guid}", {}, headers_for(developer)
        expect(last_response.status).to eq(200)
        expect(parse(last_response.body)["entity"]).to include("public" => true)
      end
    end

    describe 'service plans active flag' do
      let!(:active_plan) { ServicePlan.make(public: true, active: true) }
      let!(:inactive_plan) { ServicePlan.make(public: true, active: false) }

      context 'when the user is admin' do
        it 'returns both active and inactive plans' do
          get '/v2/service_plans', {}, admin_headers
          expect(last_response.status).to eq(200)
          expect(parse(last_response.body)['total_results']).to eq(2)
        end

        it 'returns just the inactive plans when filtered for active:f' do
          get '/v2/service_plans?q=active:f', {}, admin_headers
          expect(last_response.status).to eq(200)
          expect(parse(last_response.body)['total_results']).to eq(1)
          expect(parse(last_response.body)['resources'].first['entity']['active']).to eq(false)
        end
      end

      it 'returns just the active plans when the user is not admin' do
        get '/v2/service_plans', {}, headers_for(developer)
        expect(last_response.status).to eq(200)
        expect(parse(last_response.body)['total_results']).to eq(1)
        expect(parse(last_response.body)['resources'].first['entity']['active']).to eq(true)
      end
    end

    describe "GET", "/v2/service_plans" do
      before do
        ServicePlan.make(active: true, public: true)
        ServicePlan.make(active: false, public: true)
        ServicePlan.make(active: true, public: false)
        ServicePlan.make(active: false, public: false)
      end

      it 'displays all service plans' do
        get "/v2/service_plans", {}, admin_headers
        expect(last_response.status).to eq 200

        plans = ServicePlan.all
        expected_plan_guids = plans.map(&:guid)
        expected_service_guids = plans.map(&:service).map(&:guid).uniq

        returned_plan_guids = decoded_response.fetch('resources').map do |res|
          res['metadata']['guid']
        end

        returned_service_guids = decoded_response.fetch('resources').map do |res|
          res['entity']['service_guid']
        end

        expect(returned_plan_guids).to match_array expected_plan_guids
        expect(returned_service_guids).to match_array expected_service_guids
      end

      context 'when the user is not logged in' do
        let(:headers) { headers_for(nil) }

        it 'returns plans that are public and active' do
          get "/v2/service_plans", {}, headers
          expect(last_response.status).to eq 200

          public_and_active_plans = ServicePlan.where(active: true, public: true).all
          expected_plan_guids = public_and_active_plans.map(&:guid)
          expected_service_guids = public_and_active_plans.map(&:service).map(&:guid).uniq

          returned_plan_guids = decoded_response.fetch('resources').map do |res|
            res['metadata']['guid']
          end

          returned_service_guids = decoded_response.fetch('resources').map do |res|
            res['entity']['service_guid']
          end

          expect(returned_plan_guids).to match_array expected_plan_guids
          expect(returned_service_guids).to match_array expected_service_guids
        end

        it 'does not allow the unauthed user to use inline-relations-depth' do
          get "/v2/service_plans?inline-relations-depth=1", {}, headers
          plans = decoded_response.fetch('resources').map{ |plan| plan['entity'] }
          plans.each do |plan|
            expect(plan['service_instances']).to be_nil
          end
        end
      end
    end

    describe "POST", "/v2/service_plans" do
      let(:service) { Service.make }

      it 'requires authentication' do
        post '/v2/service_plans', '{}', headers_for(nil)
        expect(last_response.status).to eq 401
      end

      it "accepts a request with unique_id" do
        payload = ServicePlansController::CreateMessage.new(
          :name => 'foo',
          :free => false,
          :description => "We don't need no stinking plan'",
          :extra => '{"thing": 2}',
          :service_guid => service.guid,
          :unique_id => Sham.unique_id,
        ).encode
        post "/v2/service_plans", payload, json_headers(admin_headers)
        expect(last_response.status).to eq(201)
      end

      it 'makes the service plan public by default' do
        payload_without_public = ServicePlansController::CreateMessage.new(
          :name => 'foo',
          :free => false,
          :description => "We don't need no stinking plan'",
          :service_guid => service.guid,
          :unique_id => Sham.unique_id,
        ).encode
        post '/v2/service_plans', payload_without_public, json_headers(admin_headers)
        expect(last_response.status).to eq(201)
        plan_guid = decoded_response.fetch('metadata').fetch('guid')
        expect(ServicePlan.first(:guid => plan_guid).public).to be true
      end
    end

    describe "PUT", "/v2/service_plans/:guid" do
      it 'requires authentication' do
        plan = ServicePlan.make
        put "/v2/service_plans/#{plan.guid}", '{}', headers_for(nil)
        expect(last_response.status).to eq 401
      end

      it "updates the unique_id attribute" do
        service_plan = ServicePlan.make
        old_unique_id = service_plan.unique_id
        new_unique_id = old_unique_id.reverse
        payload = Yajl::Encoder.encode({"unique_id" => new_unique_id})

        put "/v2/service_plans/#{service_plan.guid}", payload, json_headers(admin_headers)

        service_plan.reload
        expect(last_response.status).to be == 201
        expect(service_plan.unique_id).to be == new_unique_id
      end

      context "when the given unique_id is already taken" do
        it "returns an error response" do
          service_plan = ServicePlan.make
          other_service_plan = ServicePlan.make
          payload = Yajl::Encoder.encode({"unique_id" => other_service_plan.unique_id})

          put "/v2/service_plans/#{service_plan.guid}", payload, json_headers(admin_headers)

          expect(last_response.status).to be == 400
          expect(decoded_response.fetch('code')).to eql(110001)
          expect(decoded_response.fetch('error_code')).to eql('CF-ServicePlanInvalid')
          expect(decoded_response.fetch('description')).to eql("The service plan is invalid: Plan ids must be unique")
        end
      end
    end

    describe "DELETE", "/v2/service_plans/:guid" do

      let(:service_plan) { ServicePlan.make }

      it 'requires authentication' do
        delete "/v2/service_plans/#{service_plan.guid}", '{}', headers_for(nil)
        expect(last_response.status).to eq 401
      end

      it "should prevent recursive deletions if there are any instances" do
        ManagedServiceInstance.make(:service_plan => service_plan)
        delete "/v2/service_plans/#{service_plan.guid}?recursive=true", {}, admin_headers
        expect(last_response.status).to eq(400)

        expect(decoded_response.fetch('code')).to eq(10006)
        expect(decoded_response.fetch('description')).to eq('Please delete the service_instances associations for your service_plans.')
      end
    end
  end
end
