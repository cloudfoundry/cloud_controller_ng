# Copyright (c) 2009-2011 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::App do
    # FIXME: make space_id a relation check that checks the id and the url
    # part.  do everywhere
    it_behaves_like "a CloudController API", {
      :path                => "/v2/apps",
      :model               => Models::App,
      :basic_attributes    => [:name, :space_guid, :runtime_guid, :framework_guid],
      :required_attributes => [:name, :space_guid, :runtime_guid, :framework_guid],
      :unique_attributes   => [:name, :space_guid],
      :queryable_attributes => :name,
      :many_to_one_collection_ids => {
        :space      => lambda { |app| Models::Space.make  },
        :framework  => lambda { |app| Models::Framework.make },
        :runtime    => lambda { |app| Models::Runtime.make   }
      },
      :many_to_many_collection_ids => {
        :routes => lambda { |app|
          domain = Models::Domain.make(
            :owning_organization => app.space.organization
          )
          app.space.organization.add_domain(domain)
          app.space.add_domain(domain)
          route = Models::Route.make(:domain => domain, :space => app.space)
        }
      },
      :one_to_many_collection_ids  => {
        :service_bindings => lambda { |app|
          service_instance = Models::ServiceInstance.make(
            :space => app.space
          )
          Models::ServiceBinding.make(
            :app => app,
            :service_instance => service_instance
          )
        }
      }
    }

    let(:admin_headers) do
      user = Models::User.make(:admin => true)
      headers_for(user)
    end

    describe "validations" do
      let(:app_obj)   { Models::App.make }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      describe "env" do
        it "should allow an empty environment" do
          hash = {}
          update_hash = { :environment_json => hash }

          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 201
        end

        it "should allow multiple variables" do
          hash = { :abc => 123, :def => "hi" }
          update_hash = { :environment_json => hash }
          put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
          last_response.status.should == 201
        end

        [ "VMC", "vmc", "VCAP", "vcap" ].each do |k|
          it "should not allow entries to start with #{k}" do
            hash = { :abc => 123, "#{k}_abc" => "hi" }
            update_hash = { :environment_json => hash }
            put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers)
            last_response.status.should == 400
            decoded_response["description"].should match /environment_json reserved_key:#{k}_abc/
          end
        end
      end
    end

    describe "command" do
      let(:app_obj)   { Models::App.make }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      it "should have no command entry in the metadata if not provided" do
        get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers)
        last_response.status.should == 200
        decoded_response["entity"]["command"].should be_nil
        decoded_response["entity"]["metadata"].should be_nil
      end

      it "should set the command on the app metadata" do
        put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:command => "foobar"), json_headers(admin_headers)
        last_response.status.should == 201
        decoded_response["entity"]["command"].should == "foobar"
        decoded_response["entity"]["metadata"].should be_nil
      end
    end

    describe "sync/async staging" do
      context "when app will be staged" do
        let(:app_obj) { Models::App.make(:package_hash => "abc", :state => "STOPPED") }

        context "when stage_async flag is in params" do
          it "stages the app asynchronously" do
            AppStager.should_receive(:stage_app) do |app, options|
              app.id.should == app_obj.id
              options.should == {:async => true}
              AppStager::Response.new({})
            end
            put "/v2/apps/#{app_obj.guid}?stage_async=1", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          end

          it "returns X-App-Staging-Log header with staging log url" do
            stager_response = AppStager::Response.new("task_streaming_log_url" => "streaming-log-url")
            AppStager.stub(:stage_app => stager_response)

            put "/v2/apps/#{app_obj.guid}?stage_async=1", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
            last_response.status.should == 201
            last_response.headers["X-App-Staging-Log"].should == "streaming-log-url"
          end
        end

        context "when stage_async flag is not in params" do
          it "stages the app synchronously" do
            AppStager.should_receive(:stage_app) do |app, options|
              app.id.should == app_obj.id
              options.should == {:async => false}
            end
            put "/v2/apps/#{app_obj.guid}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
          end
        end
      end

      context "when app will not be staged" do
        let(:app_obj) { Models::App.make(:state => "STOPPED") }

        it "does not add X-App-Staging-Log" do
          put "/v2/apps/#{app_obj.guid}?stage_async=1", Yajl::Encoder.encode({}), json_headers(admin_headers)
          last_response.status.should == 201
          last_response.headers.should_not have_key("X-App-Staging-Log")
        end
      end
    end

    describe "on route change" do
      let(:space) { Models::Space.make }
      let(:domain) do
        space.add_domain(
          :name => "jesse.cloud",
          :wildcard => true,
          :owning_organization => space.organization,
        )
      end

      before :each do
        reset_database

        user = make_developer_for_space(space)
        # keeping the headers here so that it doesn't reset the global config...
        @headers_for_user = headers_for(user)
        @app = Models::App.make(
          :space => space,
          :state => "STARTED",
        )
        # OK I'm cheating here to skip staging...
        @app.update(
          :package_hash => "abc",
          :droplet_hash => "def",
          :package_state => "STAGED",
        )
        @app_url = "/v2/apps/#{@app.guid}"
      end

      it "sends a dea.update message when we add one url through PUT /v2/apps/:guid" do
        route = domain.add_route(
          :host => "app",
          :space => space,
        )

        MessageBus.instance.should_receive(:publish).with(
          "dea.update",
          json_match(hash_including(
            "uris" => ["app.jesse.cloud"]
          )),
        )

        put(
          @app_url,
          App::UpdateMessage.new(
            :route_guids => [route.guid],
          ).encode,
          @headers_for_user,
        )
        last_response.status.should == 201
      end

      it "sends a dea.update message when we add one url through PUT /v2/apps/:guid/routes"

      it "sends a dea.update message dea.update when we remove a url through PUT /v2/apps/:guid" do
        bar_route = @app.add_route(
          :host => "bar",
          :space => space,
          :domain => domain,
        )
        route = @app.add_route(
          :host => "foo",
          :space => space,
          :domain => domain,
        )
        get "#{@app_url}/routes", {}, @headers_for_user
        decoded_response["resources"].map { |r|
          r["metadata"]["guid"]
        }.sort.should == [bar_route.guid, route.guid].sort

        MessageBus.instance.should_receive(:publish).with(
          "dea.update",
          json_match(hash_including(
            "uris" => ["foo.jesse.cloud"],
          )),
        )

        put(
          @app_url,
          App::UpdateMessage.new(
            :route_guids => [route.guid],
          ).encode,
          @headers_for_user,
        )
        last_response.status.should == 201
      end

      it "sends a dea.update message when we remove one url through PUT /v2/apps/:guid/routes"
    end

    describe "Permissions" do
      include_context "permissions"

      before do
        @obj_a = Models::App.make(:space => @space_a)
        @obj_b = Models::App.make(:space => @space_b)
      end

      let(:creation_req_for_a) do
        Yajl::Encoder.encode(
          :name => Sham.name,
          :space_guid => @space_a.guid,
          :framework_guid => Models::Framework.make.guid,
          :runtime_guid => Models::Runtime.make.guid)
      end

      let(:update_req_for_a) do
        Yajl::Encoder.encode(:name => Sham.name)
      end

      describe "Org Level Permissions" do
        describe "OrgManager" do
          let(:member_a) { @org_a_manager }
          let(:member_b) { @org_b_manager }

          include_examples "permission checks", "OrgManager",
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "OrgUser" do
          let(:member_a) { @org_a_member }
          let(:member_b) { @org_b_member }

          include_examples "permission checks", "OrgUser",
            :model => Models::App,
            :path => "/v2/apps",
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
            :model => Models::App,
            :path => "/v2/apps",
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
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
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
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end

        describe "Developer" do
          let(:member_a) { @space_a_developer }
          let(:member_b) { @space_b_developer }

          include_examples "permission checks", "Developer",
            :model => Models::App,
            :path => "/v2/apps",
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
            :model => Models::App,
            :path => "/v2/apps",
            :enumerate => 0,
            :create => :not_allowed,
            :read => :allowed,
            :modify => :not_allowed,
            :delete => :not_allowed
        end
      end
    end

    describe "Quota enforcement" do
      let(:quota) { Models::QuotaDefinition.make(:memory_limit => 0) }

      context "quota" do
        it "should enforce quota check on memory" do
          org = Models::Organization.make(:quota_definition => quota)
          space = Models::Space.make(:organization => org)
          req = Yajl::Encoder.encode(:name => Sham.name,
                                     :space_guid => space.guid,
                                     :memory => 128,
                                     :framework_guid => Models::Framework.make.guid,
                                     :runtime_guid => Models::Runtime.make.guid)

          post("/v2/apps", req, headers_for(make_developer_for_space(space)))

          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's memory limit/
        end
      end
    end
  end
end
