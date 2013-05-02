require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::ServicePlan do

    it_behaves_like "a CloudController API", {
      :path => "/v2/service_plans",
      :model => Models::ServicePlan,
      :basic_attributes => [:name, :free, :description, :service_guid, :extra, :unique_id],
      :required_attributes => [:name, :free, :description, :service_guid],
      :unique_attributes => [:name, :service_guid],
      :extra_attributes => [:extra],
      :one_to_many_collection_ids => {
        :service_instances => lambda { |service_plan| Models::ServiceInstance.make(:service_plan => service_plan) }
      }
    }

    include_examples "uaa authenticated api", path: "/v2/service_plans"
    include_examples "enumerating objects", path: "/v2/service_plans", model: Models::ServicePlan
    include_examples "reading a valid object", path: "/v2/service_plans", model: Models::ServicePlan, basic_attributes: %w(name free description service_guid extra unique_id)
    include_examples "operations on an invalid object", path: "/v2/service_plans"
    include_examples "creating and updating", path: "/v2/service_plans", model: Models::ServicePlan, required_attributes: %w(name free description service_guid), unique_attributes: %w(name service_guid), extra_attributes: %w(extra)
    include_examples "deleting a valid object", path: "/v2/service_plans", model: Models::ServicePlan,
      one_to_many_collection_ids: {:service_instances => lambda { |service_plan| Models::ServiceInstance.make(:service_plan => service_plan) }
      },
      one_to_many_collection_ids_without_url: {}
    include_examples "collection operations", path: "/v2/service_plans", model: Models::ServicePlan,
      one_to_many_collection_ids: {
        service_instances: lambda { |service_plan| Models::ServiceInstance.make(service_plan: service_plan) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}

    shared_examples "enumerate and read plan only" do |perm_name|
      include_examples "permission checks", perm_name,
        :model => Models::ServicePlan,
        :path => "/v2/service_plans",
        :permissions_overlap => true,
        :enumerate => 7,
        :create => :not_allowed,
        :read => :allowed,
        :modify => :not_allowed,
        :delete => :not_allowed
    end

    describe "Permissions" do
      include_context "permissions"

      before(:all) do
        reset_database
        5.times do
          Models::ServicePlan.make
        end
        @obj_a = Models::ServicePlan.make
        @obj_b = Models::ServicePlan.make
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :service_guid => Models::Service.make.guid,
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

    let(:admin) { VCAP::CloudController::Models::User.make(:admin => true) }
    let(:developer) { make_developer_for_space(Models::Space.make) }

    describe "modifying service plans" do
      let!(:plan) { Models::ServicePlan.make }
      let(:body) { Yajl::Encoder.encode("public" => false) }

      context "a cf admin" do
        it "can modify service plans" do
          put "/v2/service_plans/#{plan.guid}", body, headers_for(admin)
          last_response.status.should == 201
          plan.reload.public.should be_false
        end
      end

      context "otherwise" do
        it "cannot modify service plans" do
          put "/v2/service_plans/#{plan.guid}", body, headers_for(developer)
          last_response.status.should == 403
          plan.reload.public.should be_true
        end
      end
    end

    describe "non public service plans" do
      let!(:private_plan) { Models::ServicePlan.make(public: false) }

      let(:plan_guids) do
        decoded_response.fetch('resources').collect do |r|
          r.fetch('metadata').fetch('guid')
        end
      end

      it "is not visible to users from normal organization" do
        get '/v2/service_plans', {}, headers_for(developer)
        plan_guids.should_not include(private_plan.guid)
      end

      it "is visible to users from privileged organizations" do
        organization = developer.organizations.first
        VCAP::CloudController::SecurityContext.stub(:current_user_is_admin?) { true }
        organization.update(:can_access_non_public_plans => true)
        get '/v2/service_plans', {}, headers_for(developer)
        plan_guids.should include(private_plan.guid)
      end

      it "is visible to cf admin" do
        get '/v2/service_plans', {}, headers_for(admin)
        plan_guids.should include(private_plan.guid)
      end
    end
  end

  describe "POST", "/v2/service_plans" do
    let(:service) { Models::Service.make }
    it "accepts a request with unique_id" do
      payload = ServicePlan::CreateMessage.new(
        :name => 'foo',
        :free => false,
        :description => "We don't need no stinking plan'",
        :extra => '{"thing": 2}',
        :service_guid => service.guid,
        :unique_id => Sham.unique_id,
      ).encode
      post "/v2/service_plans", payload, admin_headers
      last_response.status.should eq(201)
    end
  end

  describe "PUT", "/v2/service_plans/:guid" do
    it "rejects updating unique_id" do
      service_plan = Models::ServicePlan.make
      new_unique_id = service_plan.unique_id.reverse
      payload = Yajl::Encoder.encode({"unique_id" => new_unique_id})
      put "/v2/service_plans/#{service_plan.guid}", payload, admin_headers
      last_response.status.should eq 400
    end
  end
end
