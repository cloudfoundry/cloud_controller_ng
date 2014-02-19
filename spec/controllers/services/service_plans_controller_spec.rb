require "spec_helper"

module VCAP::CloudController
  describe ServicePlansController, :services, type: :controller do
    include_examples "uaa authenticated api", path: "/v2/service_plans"
    include_examples "enumerating objects", path: "/v2/service_plans", model: ServicePlan
    include_examples "reading a valid object", path: "/v2/service_plans", model: ServicePlan,
                     basic_attributes: %w(name free description service_guid extra unique_id)
    include_examples "operations on an invalid object", path: "/v2/service_plans"
    include_examples "creating and updating", path: "/v2/service_plans", model: ServicePlan,
                     required_attributes: %w(name free description service_guid),
                     extra_attributes: {extra: ->{Sham.extra}}
    include_examples "collection operations", path: "/v2/service_plans", model: ServicePlan,
      one_to_many_collection_ids: {
        service_instances: lambda { |service_plan| ManagedServiceInstance.make(service_plan: service_plan) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}

    shared_examples "enumerate and read plan only" do |perm_name|
      include_examples "permission enumeration", perm_name,
        :name => 'service plan',
        :path => "/v2/service_plans",
        :permissions_overlap => true,
        :enumerate => 7
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        5.times { ServicePlan.make }
        @obj_a = ServicePlan.make
        @obj_b = ServicePlan.make
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :service_guid => Service.make.guid,
          :name => Sham.name,
          :free => false,
          :description => Sham.description)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:description => Sham.description)
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
          last_response.status.should == 201
          plan.reload.public.should be_false
        end
      end

      context "otherwise" do
        it "cannot modify service plans" do
          put "/v2/service_plans/#{plan.guid}", body, json_headers(headers_for(developer))
          last_response.status.should == 403
          plan.reload.public.should be_true
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
        plan_guids.should_not include(private_plan.guid)
      end

      it "is visible to users from organizations with access to the plan" do
        organization = developer.organizations.first
        VCAP::CloudController::ServicePlanVisibility.create(
          organization: organization,
          service_plan: private_plan,
        )
        get '/v2/service_plans', {}, headers_for(developer)
        plan_guids.should include(private_plan.guid)
      end

      it "is visible to cf admin" do
        get '/v2/service_plans', {}, admin_headers
        plan_guids.should include(private_plan.guid)
      end
    end

    describe "public service plans" do
      let!(:public_plan) { ServicePlan.make(public: true) }

      it "should return correct visibility" do
        get "/v2/service_plans/#{public_plan.guid}", {}, headers_for(developer)
        last_response.status.should eq(200)
        expect(parse(last_response.body)["entity"]).to include("public" => true)
      end
    end
  end

  describe "POST", "/v2/service_plans" do
    let(:service) { Service.make }
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
      last_response.status.should eq(201)
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
      last_response.status.should eq(201)
      plan_guid = decoded_response.fetch('metadata').fetch('guid')
      ServicePlan.first(:guid => plan_guid).public.should be_true
    end
  end

  describe "PUT", "/v2/service_plans/:guid" do
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
        expect(decoded_response.fetch('types')).to eql(['ServicePlanInvalid', 'Error'])
        expect(decoded_response.fetch('description')).to eql("The service plan is invalid: plan id '#{other_service_plan.unique_id}' is taken")
      end
    end
  end

  describe "DELETE", "/v2/service_plans/:guid" do

    let(:service_plan) { ServicePlan.make }

    it "should prevent recursive deletions if there are any instances" do
      ManagedServiceInstance.make(:service_plan => service_plan)
      delete "/v2/service_plans/#{service_plan.guid}?recursive=true", {}, admin_headers
      expect(last_response.status).to eq(400)

      decoded_response.fetch('code').should == 10006
      decoded_response.fetch('description').should == 'Please delete the service_instances associations for your service_plans.'
    end
  end
end
