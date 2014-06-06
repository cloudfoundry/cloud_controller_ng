require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::RoutesController do
    it_behaves_like "an authenticated endpoint", path: "/v2/routes"
    include_examples "enumerating objects", path: "/v2/routes", model: Route
    include_examples "reading a valid object", path: "/v2/routes", model: Route, basic_attributes: %w(host domain_guid space_guid)
    include_examples "operations on an invalid object", path: "/v2/routes"
    include_examples "deleting a valid object", path: "/v2/routes", model: Route, one_to_many_collection_ids: {}
    include_examples "creating and updating", path: "/v2/routes", model: Route,
                     required_attributes: %w(domain_guid space_guid),
                     unique_attributes: %w(host domain_guid),
                     extra_attributes: {host: -> { Sham.host }},
                     create_attribute: lambda { |name, route|
                       case name.to_sym
                         when :space_guid
                           route.space.guid
                         when :domain_guid
                           domain = PrivateDomain.make(owning_organization: route.space.organization,)
                           domain.guid
                         when :host
                           Sham.host
                       end
                     },
                     create_attribute_reset: lambda { @space = nil }

    describe "Permissions" do
      shared_examples "route permissions" do
        describe "Org Level Permissions" do
          describe "OrgManager" do
            let(:member_a) { @org_a_manager }
            let(:member_b) { @org_b_manager }

            include_examples "permission enumeration", "OrgManager",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 1
          end

          describe "OrgUser" do
            let(:member_a) { @org_a_member }
            let(:member_b) { @org_b_member }

            include_examples "permission enumeration", "OrgUser",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 0
          end

          describe "BillingManager" do
            let(:member_a) { @org_a_billing_manager }
            let(:member_b) { @org_b_billing_manager }

            include_examples "permission enumeration", "BillingManager",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 0
          end

          describe "Auditor" do
            let(:member_a) { @org_a_auditor }
            let(:member_b) { @org_b_auditor }

            include_examples "permission enumeration", "Auditor",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 1
          end
        end

        describe "App Space Level Permissions" do
          describe "SpaceManager" do
            let(:member_a) { @space_a_manager }
            let(:member_b) { @space_b_manager }

            include_examples "permission enumeration", "SpaceManager",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 1
          end

          describe "Developer" do
            let(:member_a) { @space_a_developer }
            let(:member_b) { @space_b_developer }

            include_examples "permission enumeration", "Developer",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 1
          end

          describe "SpaceAuditor" do
            let(:member_a) { @space_a_auditor }
            let(:member_b) { @space_b_auditor }

            include_examples "permission enumeration", "SpaceAuditor",
              :name => 'route',
              :path => "/v2/routes",
              :enumerate => 1
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
          @domain_a = PrivateDomain.make(:owning_organization => @org_a)
          @obj_a = Route.make(:domain => @domain_a, :space => @space_a)

          @domain_b = PrivateDomain.make(:owning_organization => @org_b)
          @obj_b = Route.make(:domain => @domain_b, :space => @space_b)
        end

        include_examples "route permissions"
      end
    end
  end

  describe "on app change" do
    before do
      space = Space.make
      user = make_developer_for_space(space)
      @headers_for_user = headers_for(user)
      @route = PrivateDomain.make(
        :name => "jesse.cloud",
        :owning_organization => space.organization,
      ).add_route(
        :host => "foo",
        :space => space,
      )
      @foo_app = AppFactory.make(
        :name   => "foo",
        :space  => space,
        :state  => "STARTED",
        :guid   => "guid-foo",
        :package_hash => "abc",
        :droplet_hash => "def",
        :package_state => "STAGED",
      )
      @bar_app = AppFactory.make(
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
        RoutesController::UpdateMessage.new(
          :app_guids => [@foo_app.guid, @bar_app.guid],
        ).encode,
        json_headers(@headers_for_user)
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
        RoutesController::UpdateMessage.new(
          :app_guids => [@bar_app.guid],
        ).encode,
        json_headers(@headers_for_user)
      )
      last_response.status.should == 201
    end
  end
end
