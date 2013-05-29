require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Service do
    include_examples "uaa authenticated api", path: "/v2/services"
    include_examples "enumerating objects", path: "/v2/services", model: Models::Service
    include_examples "reading a valid object", path: "/v2/services", model: Models::Service, basic_attributes: %w(label provider url description version)
    include_examples "operations on an invalid object", path: "/v2/services"
    include_examples "creating and updating", path: "/v2/services", model: Models::Service, required_attributes: %w(label provider url description version), unique_attributes: %w(label provider), extra_attributes: %w(extra)
    include_examples "deleting a valid object", path: "/v2/services", model: Models::Service,
      one_to_many_collection_ids: {:service_plans => lambda { |service| Models::ServicePlan.make(:service => service) }},
      one_to_many_collection_ids_without_url: {}
    include_examples "collection operations", path: "/v2/services", model: Models::Service,
      one_to_many_collection_ids: {
        service_plans: lambda { |service| Models::ServicePlan.make(service: service) }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {}

    shared_examples "enumerate and read service only" do |perm_name|
      include_examples "permission checks", perm_name,
        :model => Models::Service,
        :path => "/v2/services",
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
        @obj_a = Models::ServicePlan.make.service
        @obj_b = Models::ServicePlan.make.service
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :label => Sham.label,
          :provider => Sham.provider,
          :url => Sham.url,
          :description => Sham.description,
          :version => Sham.version)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:label => Sham.label)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "enumerate and read service only", "OrgManager"
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "enumerate and read service only", "OrgUser"
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "enumerate and read service only", "BillingManager"
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "enumerate and read service only", "Auditor"
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "enumerate and read service only", "SpaceManager"
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "enumerate and read service only", "Developer"
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "enumerate and read service only", "SpaceAuditor"
        end
      end
    end

    describe "get /v2/services" do
      let(:user) {VCAP::CloudController::Models::User.make  }
      let (:headers) do
        headers_for(user)
      end

      before(:each) do
        reset_database
        @active = 3.times.map { Models::Service.make(:active => true).tap{|svc| Models::ServicePlan.make(:service => svc) } }
        @inactive = 2.times.map { Models::Service.make(:active => false).tap{|svc| Models::ServicePlan.make(:service => svc) } }
      end

      def decoded_guids
        decoded_response["resources"].map { |r| r["metadata"]["guid"] }
      end

      it "should get all services" do
        get "/v2/services", {}, headers
        last_response.should be_ok
        decoded_guids.should =~ (@active + @inactive).map(&:guid)
      end


      context "with an offering that has private plans" do
        before(:each) do
          @svc_all_private = @active.first
          @svc_all_private.service_plans.each{|plan| plan.update(:public => false) }
          @svc_one_public = @active.last
          Models::ServicePlan.make(service: @svc_one_public, public: false)
        end

        it "should remove the offering when I cannot see any of the plans" do
          get "/v2/services", {}, headers
          last_response.should be_ok
          decoded_guids.should include(@svc_one_public.guid)
          decoded_guids.should_not include(@svc_all_private.guid)
        end

        it "should return the offering when I can see at least one of the plans" do
          user.update(:admin => true)
          get "/v2/services", {}, headers
          last_response.should be_ok
          decoded_guids.should include(@svc_one_public.guid)
          decoded_guids.should include(@svc_all_private.guid)
        end
      end

      describe "get /v2/services?q=active:<t|f>" do
        it "can remove inactive services" do
          # Sequel stores 'true' and 'false' as 't' and 'f' in sqlite, so with
          # sqlite, instead of 'true' or 'false', the parameter must be specified
          # as 't' or 'f'. But in postgresql, either way is ok.
          get "/v2/services?q=active:t", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @active.map(&:guid)
        end

        it "can only get inactive services" do
          get "/v2/services?q=active:f", {}, headers
          last_response.should be_ok
          decoded_guids.should =~ @inactive.map(&:guid)
        end
      end
    end

    describe "POST", "/v2/services" do
      it "accepts a request with unique_id" do
        payload = VCAP::CloudController::Service::CreateMessage.new(
          :label => 'foo',
          :provider => 'phan',
          :url => Sham.url,
          :description => 'd',
          :version => 'v',
          :unique_id => Sham.unique_id,
        ).encode
        post "/v2/services", payload, admin_headers
        last_response.status.should eq(201)
      end
    end

    describe "PUT", "/v2/services/:guid" do
      it "rejects updating unique_id" do
        service = Models::Service.make
        new_unique_id = service.unique_id.reverse
        payload = Yajl::Encoder.encode({"unique_id" => new_unique_id})
        put "/v2/services/#{service.guid}", payload, admin_headers
        last_response.status.should eq 400
      end
    end
  end
end
