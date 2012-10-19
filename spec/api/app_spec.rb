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
          route = Models::Route.make(:domain => domain)
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

    describe "staging" do
      let(:app_obj)   { Models::App.make }

      it "should not restage on update if staging is not needed" do
        AppStager.should_not_receive(:stage_app)
        app_obj.package_hash = "abc"
        app_obj.droplet_hash = "def"
        app_obj.save
        app_obj.needs_staging?.should be_false
        req = Yajl::Encoder.encode(:instances => app_obj.instances + 1)
        put "/v2/apps/#{app_obj.guid}", req, json_headers(admin_headers)
        last_response.status.should == 201
      end

      it "should restage on update if staging is needed" do
        AppStager.should_receive(:stage_app)
        app_obj.package_hash = "abc"
        app_obj.save
        app_obj.needs_staging?.should be_true
        req = Yajl::Encoder.encode(:instances => app_obj.instances + 1)
        put "/v2/apps/#{app_obj.guid}", req, json_headers(admin_headers)
        last_response.status.should == 201
      end
    end

    describe "state updates" do
      let(:app_obj) do
        app = Models::App.make
        # haxx to make the app appear staged
        app.package_hash = "abc"
        app.droplet_hash = "def"
        app
      end

      it "should start an app when moving from STOPPED to STARTED" do
        app_obj.state = "STOPPED"
        app_obj.save
        req = Yajl::Encoder.encode(:state => "STARTED")
        DeaClient.should_receive(:start)
        put "/v2/apps/#{app_obj.guid}", req, json_headers(admin_headers)
        last_response.status.should == 201
      end

      it "should stop an app when moving from STARTED to STOPPED" do
        app_obj.state = "STARTED"
        app_obj.save
        req = Yajl::Encoder.encode(:state => "STOPPED")
        DeaClient.should_receive(:stop)
        put "/v2/apps/#{app_obj.guid}", req, json_headers(admin_headers)
        last_response.status.should == 201
      end
    end

    describe "instance updates" do
      let(:app_obj) do
        app = Models::App.make
        # haxx to make the app appear staged
        app.package_hash = "abc"
        app.droplet_hash = "def"
        app
      end

      it "should change the running instances for an already started app" do
        app_obj.state = "STARTED"
        app_obj.instances = 3
        app_obj.save

        req = Yajl::Encoder.encode(:instances => 5)
        DeaClient.should_receive(:change_running_instances).with(kind_of(Models::App), 2)
        put "/v2/apps/#{app_obj.guid}", req, json_headers(admin_headers)
        last_response.status.should == 201
      end
    end

    describe "delete" do
      let(:app_obj) { Models::App.make }

      context "app started" do
        it "should send a delete to the deas" do
          app_obj.state = "STARTED"
          app_obj.save

          # we can't do a direct comparison due to potential minor timestamp differences,
          # and we can't do the .should inside the block because sequel will
          # supress it
          stopped_app = nil
          DeaClient.should_receive(:stop) do |obj|
            stopped_app = obj
          end

          delete "/v2/apps/#{app_obj.guid}", {}, admin_headers
          stopped_app.guid.should == app_obj.guid
        end
      end

      context "app stopped" do
        it "should not send a delete to the deas" do
          app_obj.state = "STOPPED"
          app_obj.save

          DeaClient.should_not_receive(:stop)
          delete "/v2/apps/#{app_obj.guid}", {}, admin_headers
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
          :organization => space.organization,
        )

        nats = double("mock nats")
        config_override(:nats => nats)
        nats.should_receive(:publish).with(
          "dea.update",
          json_match(
            hash_including("uris" => ["app.jesse.cloud"]),
          ),
        )
        EM.run do
          put(
            @app_url,
            App::UpdateMessage.new(
              :route_guids => [route.guid],
            ).encode(),
            @headers_for_user,
          )
          EM.stop
        end
        last_response.status.should == 201
      end

      it "sends a dea.update message when we add one url through PUT /v2/apps/:guid/routes"

      it "sends a dea.update message dea.update when we remove a url through PUT /v2/apps/:guid" do
        bar_route = @app.add_route(
          :host => "bar",
          :organization => space.organization,
          :domain => domain,
        )
        route = @app.add_route(
          :host => "foo",
          :organization => space.organization,
          :domain => domain,
        )
        get "#{@app_url}/routes", {}, @headers_for_user
        decoded_response["resources"].map { |r|
          r["metadata"]["guid"]
        }.sort.should == [bar_route.guid, route.guid].sort

        nats = double("mock nats")
        config_override(:nats => nats)
        # inject mock nats
        MessageBus.configure(config)

        nats.should_receive(:publish).with(
          "dea.update",
          json_match(
            hash_including("uris" => ["foo.jesse.cloud"]),
          ),
        )
        EM.run do
          put(
            @app_url,
            App::UpdateMessage.new(
              :route_guids => [route.guid],
            ).encode,
            @headers_for_user,
          )
          EM.stop
        end
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
        Yajl::Encoder.encode(:name => Sham.name,
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
            :read => :not_allowed,
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

    describe "quota" do
      let(:cf_admin) { Models::User.make(:admin => true) }
      let(:app_obj) { Models::App.make }

      describe "create" do
        it "should fetch a quota token" do
          should_receive_quota_call
          post "/v2/apps", Yajl::Encoder.encode(:name => Sham.name,
                                                :space_guid => app_obj.space_guid,
                                                :framework_guid => app_obj.framework_guid,
                                                :runtime_guid => app_obj.runtime_guid),
                                                headers_for(cf_admin)
          last_response.status.should == 201
        end
      end

      describe "get" do
        it "should not fetch a quota token" do
          should_not_receive_quota_call
          RestController::QuotaManager.should_not_receive(:fetch_quota_token)
          get "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
          last_response.status.should == 200
        end
      end

      describe "update" do
        it "should fetch a quota token" do
          should_receive_quota_call
          put("/v2/apps/#{app_obj.guid}",
              Yajl::Encoder.encode(:name => "#{app_obj.name}_renamed"),
              headers_for(cf_admin)
             )
          last_response.status.should == 201
        end
      end

      describe "delete" do
        it "should fetch a quota token" do
          should_receive_quota_call
          delete "/v2/apps/#{app_obj.guid}", {}, headers_for(cf_admin)
          last_response.status.should == 204
        end
      end
    end
  end
end
