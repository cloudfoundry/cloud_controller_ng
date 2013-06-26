require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Space do
    include_examples "uaa authenticated api", path: "/v2/spaces"
    include_examples "querying objects", path: "/v2/spaces", model: Models::Space, queryable_attributes: %w(name)
    include_examples "enumerating objects", path: "/v2/spaces", model: Models::Space
    include_examples "reading a valid object", path: "/v2/spaces", model: Models::Space, basic_attributes: %w(name organization_guid)
    include_examples "operations on an invalid object", path: "/v2/spaces"
    include_examples "creating and updating", path: "/v2/spaces", model: Models::Space, required_attributes: %w(name organization_guid), unique_attributes: %w(name organization_guid), extra_attributes: []
    include_examples "deleting a valid object", path: "/v2/spaces", model: Models::Space,
      one_to_many_collection_ids: {
        :apps => lambda { |space| Models::App.make(:space => space) },
        :service_instances => lambda { |space| Models::ManagedServiceInstance.make(:space => space) }
      },
      one_to_many_collection_ids_without_url: {
        :routes => lambda { |space| Models::Route.make(:space => space) },
        :default_users => lambda { |space|
          user = VCAP::CloudController::Models::User.make
          space.organization.add_user(user)
          space.add_developer(user)
          space.save
          user.default_space = space
          user.save
          user
        }
      }
    include_examples "collection operations", path: "/v2/spaces", model: Models::Space,
      one_to_many_collection_ids: {
        apps: lambda { |space| Models::App.make(space: space) },
        service_instances: lambda { |space| Models::ManagedServiceInstance.make(space: space) }
      },
      one_to_many_collection_ids_without_url: {
        routes: lambda { |space| Models::Route.make(space: space) },
        default_users: lambda { |space|
          user = VCAP::CloudController::Models::User.make
          space.organization.add_user(user)
          space.add_developer(user)
          space.save
          user.default_space = space
          user.save
          user
        }
      },
      many_to_one_collection_ids: {},
      many_to_many_collection_ids: {
        developers: lambda { |space| make_user_for_space(space) },
        managers: lambda { |space| make_user_for_space(space) },
        auditors: lambda { |space| make_user_for_space(space) },
        domains: lambda { |space| make_domain_for_space(space) }
      }


    describe "data integrity" do
      let(:cf_admin) { Models::User.make(:admin => true) }
      let(:space) { Models::Space.make }

      it "should not make strings into integers" do
        space.name = "1234"
        space.save
        get "/v2/spaces/#{space.guid}", {}, headers_for(cf_admin)
        decoded_response["entity"]["name"].should == "1234"
      end
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = @space_a
        @obj_b = @space_b
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name, :organization_guid => @org_a.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "BillingManager" do
          let(:member_a) { @org_a_billing_manager }
          let(:member_b) { @org_b_billing_manager }

          include_examples "permission checks", "BillingManager",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Auditor" do
          let(:member_a) { @org_a_auditor }
          let(:member_b) { @org_b_auditor }

          include_examples "permission checks", "Auditor",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :not_allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end

      describe "App Space Level Permissions" do
        describe "SpaceManager" do
          let(:member_a) { @space_a_manager }
          let(:member_b) { @space_b_manager }

          include_examples "permission checks", "SpaceManager",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "SpaceAuditor" do
          let(:member_a) { @space_a_auditor }
          let(:member_b) { @space_b_auditor }

          include_examples "permission checks", "SpaceAuditor",
            :model => Models::Space,
            :path => "/v2/spaces",
            :enumerate => 1,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe 'GET /v2/spaces/:guid/service_instances' do
      let(:space) { Models::Space.make }
      let(:developer) { make_developer_for_space(space) }
      context 'when there are provided service instances' do
        it 'returns only the managed service instances' do
          Models::ProvidedServiceInstance.make(space: space)
          managed_service_instance = Models::ManagedServiceInstance.make(space: space)

          get "/v2/spaces/#{space.guid}/service_instances", '', headers_for(developer)

          last_response.status.should == 200
          decoded_response["resources"].should have(1).item
          decoded_response["resources"][0]["metadata"]["guid"].should == managed_service_instance.guid
        end
      end
    end
  end
end
