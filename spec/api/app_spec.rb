require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::App do
    before { configure_stacks }

    # FIXME: make space_id a relation check that checks the id and the url
    # part.  do everywhere
    it_behaves_like "a CloudController API", {
      :path                => "/v2/apps",
      :model               => Models::App,
      :basic_attributes    => [:name, :space_guid, :stack_guid],
      :required_attributes => [:name, :space_guid],
      :unique_attributes   => [:name, :space_guid],
      :queryable_attributes => :name,
      :many_to_one_collection_ids => {
        :space      => lambda { |app| Models::Space.make },
        :stack      => lambda { |app| Models::Stack.make },
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

    describe "create app" do
      let(:space_guid) { Models::Space.make.guid.to_s }
      let(:initial_hash) do
        { :name => "maria",
          :space_guid => space_guid
        }
      end

      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      subject { post "/v2/apps", Yajl::Encoder.encode(initial_hash), json_headers(admin_headers) }

      context "when name and space provided" do
        it "responds with new app data" do
          subject
          last_response.status.should == 201
          decoded_response["entity"]["name"].should == "maria"
          decoded_response["entity"]["space_guid"].should == space_guid
        end
      end

      context "when name is not provided" do
        let(:initial_hash) {{ :space_guid => space_guid }}
        it "responds with missing field name error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field name/
        end
      end

      context "when space is not provided" do
        let(:initial_hash) {{ :name => "maria" }}
        it "responds with missing field space error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /Error: Missing field space/
        end
      end

      context "when detected_buildpack is provided" do
        let(:initial_hash) do
          { :name => "maria",
            :space_guid => space_guid,
            :detected_buildpack => "buildpack"
          }
        end

        it "responds with error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /.*error.*detected_buildpack.*/i
        end
      end
    end

    describe "update app" do
      let(:space_guid) { Models::Space.make.guid.to_s }
      let(:initial_hash) do
        { :name => "maria",
          :space_guid => space_guid,
        }
      end

      let(:update_hash) do
        { :name => "maria",
          :space_guid => space_guid,
          :detected_buildpack => "buildpack"
        }
      end

      before do
        post "/v2/apps", Yajl::Encoder.encode(initial_hash), json_headers(admin_headers)
        @new_app_guid = decoded_response["metadata"]["guid"]
      end

      subject { put "/v2/apps/#{@new_app_guid}", Yajl::Encoder.encode(update_hash), json_headers(admin_headers) }

      context "when detected buildpack is not provided" do
        let(:update_hash) do
          { :name => "maria",
            :space_guid => space_guid
          }
        end

        it "should work" do
          subject
          last_response.status.should == 201
        end
      end

      context "when detected buildpack is provided" do
        it "should raise error" do
          subject
          last_response.status.should == 400
          last_response.body.should match /.*error.*detected_buildpack.*/i
        end
      end
    end

    describe "read an app" do
      let(:app_obj) { Models::App.make(:detected_buildpack => "buildpack-name") }
      let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

      subject { get "/v2/apps/#{app_obj.guid}", {}, json_headers(admin_headers) }

      it "should return the detected buildpack" do
        subject
        last_response.status.should == 200
        decoded_response["entity"]["detected_buildpack"].should eq("buildpack-name")
      end
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

        context "when stage_async query param is true" do
          ["stage_async=1", "stage_async=true"].each do |query_params|
            describe "with '#{query_params}' query params" do
              it "stages the app asynchronously" do
                received_app = nil
                received_options = nil

                AppStager.should_receive(:stage_app) do |app, options|
                  received_app = app
                  received_options = options
                  AppStagerTask::Response.new({})
                end

                put "/v2/apps/#{app_obj.guid}?#{query_params}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
                received_app.id.should == app_obj.id
                received_options.should == {:async => true}
              end

              it "returns X-App-Staging-Log header with staging log url" do
                stager_response = AppStagerTask::Response.new("task_streaming_log_url" => "streaming-log-url")
                AppStager.stub(:stage_app => stager_response)

                put "/v2/apps/#{app_obj.guid}?#{query_params}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
                last_response.status.should == 201
                last_response.headers["X-App-Staging-Log"].should == "streaming-log-url"
              end
            end
          end
        end

        context "when stage_async query param is false" do
          ["", "stage_async=0", "stage_async=false"].each do |query_params|
            describe "with '#{query_params}' query params" do
              it "stages the app synchronously" do
                received_app = nil
                received_options = nil

                AppStager.should_receive(:stage_app) do |app, options|
                  received_app = app
                  received_options = options
                  AppStagerTask::Response.new({})
                end

                put "/v2/apps/#{app_obj.guid}?#{query_params}", Yajl::Encoder.encode(:state => "STARTED"), json_headers(admin_headers)
                received_app.id.should == app_obj.id
                received_options.should == {:async => false}
              end
            end
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
          :space_guid => @space_a.guid)
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
                                     :memory => 128)

          post("/v2/apps", req, headers_for(make_developer_for_space(space)))

          last_response.status.should == 400
          decoded_response["description"].should =~ /exceeded your organization's memory limit/
        end
      end
    end
  end
end
