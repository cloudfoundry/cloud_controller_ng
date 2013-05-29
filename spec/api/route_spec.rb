require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Route do
    include_examples "uaa authenticated api", path: "/v2/routes"
    include_examples "enumerating objects", path: "/v2/routes", model: Models::Route
    include_examples "reading a valid object", path: "/v2/routes", model: Models::Route, basic_attributes: %w(host domain_guid space_guid)
    include_examples "operations on an invalid object", path: "/v2/routes"
    include_examples "deleting a valid object", path: "/v2/routes", model: Models::Route, one_to_many_collection_ids: {}, one_to_many_collection_ids_without_url: {}
    include_examples "creating and updating", path: "/v2/routes", model: Models::Route, required_attributes: %w(domain_guid space_guid), unique_attributes: %w(host domain_guid), extra_attributes: %w(host),
      create_attribute: lambda { |name|
        @space ||= Models::Space.make
        case name.to_sym
          when :space_guid
            @space.guid
          when :domain_guid
            domain = Models::Domain.make(wildcard: true, owning_organization: @space.organization,)
            @space.add_domain(domain)
            domain.guid
          when :host
            Sham.host
        end
      },
      create_attribute_reset: lambda { @space = nil }

    context "with a wildcard domain" do
      it "should allow a nil host" do
        cf_admin = Models::User.make(:admin => true)
        domain = Models::Domain.make(:wildcard => true)
        space = Models::Space.make(:organization => domain.owning_organization)
        space.add_domain(domain)
        post "/v2/routes",
          Yajl::Encoder.encode(:host => nil,
                               :domain_guid => domain.guid,
                               :space_guid => space.guid),
          headers_for(cf_admin)
        last_response.status.should == 201
      end
    end

    describe "Permissions" do

      shared_examples "route permissions" do
        describe "Org Level Permissions" do
          describe "OrgManager" do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples "permission checks", "OrgManager",
              :model => Models::Route,
              :path => "/v2/routes",
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
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 0,
              :create => :not_allowed,
              :read => :not_allowed,
              :modify => :not_allowed,
              :delete => :not_allowed
          end

          describe "BillingManager" do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples "permission checks", "BillingManager",
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 0,
              :create => :not_allowed,
              :read => :not_allowed,
              :modify => :not_allowed,
              :delete => :not_allowed
          end

          describe "Auditor" do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples "permission checks", "Auditor",
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 1,
              :create => :not_allowed,
              :read => :allowed,
              :modify => :not_allowed,
              :delete => :not_allowed
          end
        end

        describe "App Space Level Permissions" do
          describe "SpaceManager" do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples "permission checks", "SpaceManager",
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 1,
              :create => :allowed,
              :read => :allowed,
              :modify => :allowed,
              :delete => :allowed
          end

          describe "Developer" do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples "permission checks", "Developer",
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 1,
              :create => :allowed,
              :read => :allowed,
              :modify => :allowed,
              :delete => :allowed
          end

          describe "SpaceAuditor" do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples "permission checks", "SpaceAuditor",
              :model => Models::Route,
              :path => "/v2/routes",
              :enumerate => 1,
              :create => :not_allowed,
              :read => :allowed,
              :modify => :not_allowed,
              :delete => :not_allowed
          end
        end
      end

      context "with a custom domain" do
        include_context "permissions"

        let(:creation_req_for_a) do
          Yajl::Encoder.encode(:host => Sham.host,
                               :domain_guid => @domain_a.guid,
                               :space_guid => @space_a.guid)
        end

        let(:update_req_for_a) do
          Yajl::Encoder.encode(:host => Sham.host)
        end

        before do
          @domain_a = Models::Domain.make(:wildcard => true, :owning_organization => @org_a)
          @space_a.add_domain(@domain_a)
          @obj_a = Models::Route.make(:domain => @domain_a, :space => @space_a)

          @domain_b = Models::Domain.make(:wildcard => true, :owning_organization => @org_b)
          @space_b.add_domain(@domain_b)
          @obj_b = Models::Route.make(:domain => @domain_b, :space => @space_b)
        end

        include_examples "route permissions"
      end

      context "with the default serving domain" do
        include_context "permissions"

        let(:creation_req_for_a) do
          Yajl::Encoder.encode(
            :host => Sham.host,
            :domain_guid => Models::Domain.default_serving_domain.guid,
            :space_guid => @space_a.guid,
          )
        end

        let(:update_req_for_a) do
          Yajl::Encoder.encode(:host => Sham.host)
        end

        before do
          Models::Domain.default_serving_domain_name = "shared.com"
          @space_a.add_domain(Models::Domain.default_serving_domain)
          @space_b.add_domain(Models::Domain.default_serving_domain)

          @obj_a = Models::Route.make(
            :host => Sham.host,
            :domain => Models::Domain.default_serving_domain,
            :space => @space_a,
          )

          @obj_b = Models::Route.make(
            :host => Sham.host,
            :domain => Models::Domain.default_serving_domain,
            :space => @space_b,
          )
        end

        after do
          Models::Domain.default_serving_domain_name = nil
        end

        include_examples "route permissions"
      end
    end
  end

  describe "on app change" do
    before :each do
      reset_database

      space = Models::Space.make
      user = make_developer_for_space(space)
      @headers_for_user = headers_for(user)
      @route = space.add_domain(
        :name => "jesse.cloud",
        :wildcard => true,
        :owning_organization => space.organization,
      ).add_route(
        :host => "foo",
        :space => space,
      )
      @foo_app = Models::App.make(
        :name   => "foo",
        :space  => space,
        :state  => "STARTED",
        :guid   => "guid-foo",
        :package_hash => "abc",
        :droplet_hash => "def",
        :package_state => "STAGED",
      )
      @bar_app = Models::App.make(
        :name   => "bar",
        :space  => space,
        :state  => "STARTED",
        :guid   => "guid-bar",
        :package_hash => "ghi",
        :droplet_hash => "jkf",
        :package_state => "STAGED",
      )
    end

    it "sends a dea.update message after adding an app" do
      @foo_app.add_route(@route)
      get "/v2/routes/#{@route.guid}/apps", {}, @headers_for_user
      last_response.status.should == 200
      expect(decoded_response["resources"].map { |r|
        r["metadata"]["guid"]
      }).to eq [@foo_app.guid]

      DeaClient.should_receive(:update_uris)

      put(
        "/v2/routes/#{@route.guid}",
        Route::UpdateMessage.new(
          :app_guids => [@foo_app.guid, @bar_app.guid],
        ).encode,
        @headers_for_user,
      )
      last_response.status.should == 201
    end

    it "sends a dea.update message after removing an app" do
      @foo_app.add_route(@route)
      @bar_app.add_route(@route)

      get "/v2/routes/#{@route.guid}/apps", {}, @headers_for_user
      last_response.status.should == 200
      decoded_response["total_results"].should eq(2)
      decoded_response["resources"].map { |r|
        r["metadata"]["guid"]
      }.sort.should eq [@foo_app.guid, @bar_app.guid].sort

      DeaClient.should_receive(:update_uris)


      put(
        "/v2/routes/#{@route.guid}",
        Route::UpdateMessage.new(
          :app_guids => [@bar_app.guid],
        ).encode,
        @headers_for_user,
      )
      last_response.status.should == 201
    end
  end
end
