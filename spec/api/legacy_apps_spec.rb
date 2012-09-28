require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::LegacyApps do
    DEFAULT_SERVING_DOMAIN_NAME = "sharedorg.com"

    let(:user) { make_user_with_default_space }
    let(:admin) { make_user_with_default_space(:admin => true) }

    before do
      Models::Domain.default_serving_domain_name = DEFAULT_SERVING_DOMAIN_NAME
      HealthManagerClient.stub(:healthy_instances).and_return(1)
    end

    after do
      Models::Domain.default_serving_domain_name = nil
    end

    describe "GET /apps" do
      before do
        @apps = []
        7.times do
          @apps << Models::App.make(:space => user.default_space,
                                    :environment_json => {})
        end

        3.times do
          space = make_space_for_user(user)
          Models::App.make(:space => space)
        end

        get "/apps", {}, headers_for(user)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should return an array" do
        decoded_response.should be_a_kind_of(Array)
      end

      it "should only return apps for the default app space" do
        decoded_response.length.should == 7
      end

      it "should return app names" do
        names = decoded_response.map { |a| a["name"] }
        expected_names = @apps.map { |a| a.name }
        names.should == expected_names
      end
    end

    describe "GET /apps/:name" do
      before do
        # since we don't get the guid back, we use the mem attribute to
        # distinguish between apps
        @app_1 = Models::App.make(:space => user.default_space, :memory => 128)
        @app_2 = Models::App.make(:space => user.default_space, :memory => 256)
        @app_3 = Models::App.make(:space => user.default_space, :memory => 512)

        @route = Models::Route.make(
          :domain => Models::Domain.default_serving_domain,
          :organization => @app_2.space.organization
        )
        @app_2.add_route(@route)

        # used to make sure we are getting the name from the correct app space,
        # i.e. we *don't* want to get this one back
        Models::App.make(:name => @app_2.name,
                         :space => make_space_for_user(user), :memory => 1024)

      end

      it "should return empty array for nil environment" do
        Models::App.make(
          :name  => "nil_env",
          :space => user.default_space,
        )

        get "/apps/nil_env", {}, headers_for(user)
        last_response.status.should == 200
        decoded_response.should include("env" => [])
      end

      describe "GET /apps/:name_that_exists" do
        before do
          get "/apps/#{@app_2.name}", {}, headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should return a hash" do
          decoded_response.should be_a_kind_of(Hash)
        end

        it "should return the app with the correct name" do
          decoded_response["name"].should == @app_2.name
        end

        it "should return the version from the default app space" do
          decoded_response["resources"]["memory"].should == 256
        end

        it "should return the uris for the app" do
          decoded_response["uris"].should == [@route.fqdn]
        end
      end

      describe "GET /apps/:invalid_name" do
        before do
          get "/apps/name_does_not_exist", {}, headers_for(user)
        end

        it "should return an error" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", /app name could not be found: name_does_not_exist/
      end
    end

    describe "GET /apps/:name/instances/:instance_id/files/(:path)" do
      before do
        @app = Models::App.make(:space => user.default_space)
      end

      it "should delegate to v2 files api with path" do
        files_obj = mock("files")

        Files.should_receive(:new).once.
          and_return(files_obj)
        files_obj.should_receive(:dispatch).once.
          with(:files, @app.guid, "1", "path").and_return([HTTP::OK, "files"])

        get "/apps/#{@app.name}/instances/1/files/path", {}, headers_for(user)

        last_response.status.should == 200
        last_response.body.should == "files"
      end

      it "should delegate to v2 files api without path" do
        files_obj = mock("files")

        Files.should_receive(:new).once.
          and_return(files_obj)
        files_obj.should_receive(:dispatch).once.
          with(:files, @app.guid, "1", nil).and_return([HTTP::OK, "files"])

        get "/apps/#{@app.name}/instances/1/files", {}, headers_for(user)

        last_response.status.should == 200
        last_response.body.should == "files"
      end
    end

    describe "GET /apps/:name/stats" do
      before do
        @app = Models::App.make(:space => user.default_space)
      end

      it "should delegate to v2 stats api" do
        stats_obj = mock("stats")

        Stats.should_receive(:new).once.
          and_return(stats_obj)
        stats_obj.should_receive(:dispatch).once.
          with(:stats, @app.guid).and_return([HTTP::OK, "stats"])

        get "/apps/#{@app.name}/stats", {}, headers_for(user)

        last_response.status.should == 200
        last_response.body.should == "stats"
      end
    end

    describe "GET /apps/:name/instances" do
      before do
        @app = Models::App.make(:space => user.default_space)
      end

      it "should delegate to v2 instances api" do
        instances_obj = mock("instances")

        resp = Yajl::Encoder.encode({
          0 => {
            :state => "RUNNING"
          }
        })

        Instances.should_receive(:new).
          and_return(instances_obj)
        instances_obj.should_receive(:dispatch).once.
          with(:instances, @app.guid).and_return(resp)

        get "/apps/#{@app.name}/instances", {}, headers_for(user)

        last_response.status.should == 200
        decoded_response.should == {"instances" => [
          {"index" => 0, "state" => "RUNNING"}
        ]}
      end
    end

    describe "POST /apps" do
      before do
        3.times { Models::App.make }

        Models::Framework.make(:name => "sinatra")
        Models::Runtime.make(:name => "ruby18")

        Models::Framework.make(:name => "grails")
        Models::Runtime.make(:name => "java")
        @num_apps_before = Models::App.count
      end

      context "with all required parameters" do
        before do
          req = Yajl::Encoder.encode({
            :name => "app_name",
            :staging => { :framework => "sinatra", :runtime => "ruby18" },
          })

          post "/apps", req, headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should add the app to default app space" do
          app = user.default_space.apps.find(:name => "app_name")
          app.should_not be_nil
          Models::App.count.should == @num_apps_before + 1
        end
      end

      context "with legacy yeti style framework and runtime [TEAM-61]" do
        before do
          req = Yajl::Encoder.encode({
            :name => "app_name",
            :staging => { :model => "sinatra", :stack => "ruby18" }
          })

          post "/apps", req, headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should add the app to default app space" do
          app = user.default_space.apps.find(:name => "app_name")
          app.should_not be_nil
          Models::App.count.should == @num_apps_before + 1
        end
      end

      context "with an invalid framework" do
        before do
          req = Yajl::Encoder.encode({
            :name => "app_name",
            :staging => { :framework => "funky", :runtime => "ruby18" },
          })

          post "/apps", req, headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it "should not add an app" do
          Models::App.count.should == @num_apps_before
        end

        it_behaves_like "a vcap rest error response", /framework is invalid: funky/
      end

      context "with an invalid runtime" do
        before do
          req = Yajl::Encoder.encode({
            :name => "app_name",
            :staging => { :framework => "sinatra", :runtime => "cobol" },
          })

          post "/apps", req, headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it "should not add an app" do
          Models::App.count.should == @num_apps_before
        end

        it_behaves_like "a vcap rest error response", /runtime is invalid: cobol/
      end

      context "with a nil runtime" do
        before do
          req = Yajl::Encoder.encode({
            :name => "app_name",
            :staging => { :framework => "grails" }
          })

          post "/apps", req, headers_for(user)
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should set a default runtime" do
          app = user.default_space.apps_dataset[:name => "app_name"]
          app.should_not be_nil
          app.runtime.name.should == "java"
        end
      end

      context "with uris" do
        context "with a valid route" do
          before do
            req = Yajl::Encoder.encode({
              :name => "app_name",
              :staging => { :framework => "grails" },
              :uris => ["someroute.#{DEFAULT_SERVING_DOMAIN_NAME}"]
            })

            post "/apps", req, headers_for(user)
          end

          it "should return success" do
            last_response.status.should == 200
          end

          it "should set the route" do
            app = user.default_space.apps_dataset[:name => "app_name"]
            app.should_not be_nil
            app.uris.should == ["someroute.#{DEFAULT_SERVING_DOMAIN_NAME}"]
          end
        end

        context "with an invalid route" do
          let(:bad_domain) { Models::Domain.make(:name => "notonspace.com") }

          before do
            req = Yajl::Encoder.encode({
              :name => "app_name",
              :staging => { :framework => "grails" },
              :uris => ["someroute.#{DEFAULT_SERVING_DOMAIN_NAME}",
                        "anotherroute.#{bad_domain.name}"]
            })

            post "/apps", req, headers_for(user)
          end

          it "should return bad request" do
            last_response.status.should == 400
          end

          it "should not create the app" do
            app = user.default_space.apps_dataset[:name => "app_name"]
            app.should be_nil
          end

          it_behaves_like "a vcap rest error response",
            /domain is invalid: notonspace.com/
        end
      end

      describe "with env" do
        it "should add the environment variable if its legal" do
          legacy_req = Yajl::Encoder.encode(
            "name"    => "app_with_env",
            "staging" => {
              "framework" => "grails",
              "runtime"   => "java",
            },
            "env"     => [
              "jesse=awesome",
            ],
          )

          post "/apps", legacy_req, headers_for(user)

          get "/apps/app_with_env", {}, headers_for(user)

          decoded_response["env"].should == ["jesse=awesome"]
        end

        it "should not allow environment variables that start with vcap_" do
          legacy_req = Yajl::Encoder.encode(
            "name"    => "app_with_env",
            "staging" => {
              "framework" => "grails",
              "runtime"   => "java",
            },
            "env"     => [
              "vcap_foo=bar",
            ],
          )

          post "/apps", legacy_req, headers_for(user)

          last_response.status.should == 400
        end

        it 'should not allow environment variables that start with vmc_' do
          legacy_req = Yajl::Encoder.encode(
            "name"    => "app_with_env",
            "staging" => {
              "framework" => "grails",
              "runtime"   => "java",
            },
            "env"     => [
              "vmc_foo=bar",
            ],
          )

          post "/apps", legacy_req, headers_for(user)

          last_response.status.should == 400
        end
      end

      describe "with staging command" do
        it "should set the staging command if one is set" do
          legacy_req = Yajl::Encoder.encode(
            "name"    => "app_with_cmd",
            "staging" => {
              "framework" => "grails",
              "runtime"   => "java",
              "command"   => "foobar",
            }
          )

          post "/apps", legacy_req, headers_for(user)
          last_response.status.should == 200

          get "/apps/app_with_cmd", {}, headers_for(user)
          last_response.status.should == 200
          decoded_response["meta"]["command"].should == "foobar"
        end

        describe "with console" do
          it "should set the console if one is set" do
            legacy_req = Yajl::Encoder.encode(
              "name"    => "app_with_console",
              "console" => true,
              "staging" => {
                "framework" => "grails",
                "runtime"   => "java",
              }
            )

            post "/apps", legacy_req, headers_for(user)
            last_response.status.should == 200

            get "/apps/app_with_console", {}, headers_for(user)
            last_response.status.should == 200
            decoded_response["meta"]["console"].should == true
          end
        end
      end
    end

    describe "PUT /apps/:name" do
      let(:app_obj) { Models::App.make(:space => user.default_space) }

      context "with valid attributes" do
        before do
          @expected_mem = app_obj.memory * 2
          req = Yajl::Encoder.encode(:resources => { :memory => @expected_mem })
          put "/apps/#{app_obj.name}", req, headers_for(user)
          app_obj.refresh
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should update the app" do
          app_obj.memory.should == @expected_mem
        end
      end

      context "with an invalid runtime" do
        before do
          req = Yajl::Encoder.encode(:staging => { :runtime => "cobol" })
          put "/apps/#{app_obj.name}", req, headers_for(user)
        end

        it "should return bad request" do
          last_response.status.should == 400
        end

        it_behaves_like "a vcap rest error response", /runtime is invalid: cobol/
      end

      describe "with env" do
        it "should add the environment variable if its legal" do
          app = Models::App.make(
            :space  => user.default_space,
            :name   => "app_with_env",
          )
          legacy_req = Yajl::Encoder.encode(
            "env"     => [
              "jesse=awesome",
            ],
          )

          put "/apps/app_with_env", legacy_req, headers_for(user)

          get "/apps/app_with_env", {}, headers_for(user)

          decoded_response["env"].should == ["jesse=awesome"]
        end

        it "should not allow environment variables that start with vcap_" do
          app = Models::App.make(
            :space  => user.default_space,
            :name   => "app_with_env",
          )
          legacy_req = Yajl::Encoder.encode(
            "env"     => [
              "vcap_foo=bar",
            ],
          )

          put "/apps/app_with_env", legacy_req, headers_for(user)
          last_response.status.should == 400
        end

        it 'should not allow environment variables that start with vmc_' do
          app = Models::App.make(
            :space  => user.default_space,
            :name   => "app_with_env",
          )
          legacy_req = Yajl::Encoder.encode(
            "env"     => [
              "vmc_foo=bar",
            ],
          )

          put "/apps/app_with_env", legacy_req, headers_for(user)
          last_response.status.should == 400
        end
      end

      describe "PUT /apps/:invalid_name" do
        before do
          put "/apps/name_does_not_exist", {}, headers_for(user)
        end

        it "should return an error" do
          last_response.status.should == 404
        end

        it_behaves_like "a vcap rest error response", /app name could not be found: name_does_not_exist/
      end

      describe "on route change" do
        it "sends a dea.update message when adding a URL to a running app" do
          Models::App.make(
            :name => "foo",
            :space => user.default_space,
            :state => "STARTED",
          ).update(
            # I hate that implicit save on package_hash=,
            # but I'll bare with it while nothing breaks...
            :package_hash   => "abc",
            :droplet_hash   => "def",
            :package_state  => "STAGED",
          )

          nats = double("mock nats")
          nats.should_receive(:publish).with(
            "dea.update",
            json_match(
              hash_including("uris" => ["bar.sharedorg.com", "foo.sharedorg.com"]),
            ),
          )
          config_override(:nats => nats)
          EM.run do
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["bar.sharedorg.com", "foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            EM.next_tick { EM.stop }
          end
        end

        it "sends a dea.update message when removing a URL to a running app" do
          Models::App.make(
            :name => "foo",
            :space => user.default_space,
            :state => "STARTED",
          ).update(
            # I hate that implicit save on package_hash=,
            # but I'll bare with it while nothing breaks...
            :package_hash   => "abc",
            :droplet_hash   => "def",
            :package_state  => "STAGED",
          )

          black_hole = double
          black_hole.stub(:publish)
          config_override(:nats => black_hole)

          nats = double("mock nats")
          nats.should_receive(:publish).with(
            "dea.update",
            json_match(
              hash_including("uris" => ["foo.sharedorg.com"]),
            ),
          )
          EM.run do
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["bar.sharedorg.com", "foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            config_override(:nats => nats)
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            EM.next_tick { EM.stop }
          end
        end

        it "does not send a dea.update message when adding a URL to a running app" do
          Models::App.make(
            :name => "foo",
            :space => user.default_space,
            :state => "STOPPED",
          )
          nats = double("mock nats")
          nats.should_not_receive(:publish)
          config_override(:nats => nats)
          EM.run do
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["bar.sharedorg.com", "foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            EM.next_tick { EM.stop }
          end
        end

        it "does not send a dea.update message when removing a URL to a running app" do
          Models::App.make(
            :name => "foo",
            :space => user.default_space,
            :state => "STOPPED",
          )
          nats = double("mock nats")
          nats.should_not_receive(:publish)
          config_override(:nats => nats)
          EM.run do
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["bar.sharedorg.com", "foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            put(
              "/apps/foo",
              Yajl::Encoder.encode(
                :uris => ["foo.sharedorg.com"],
              ),
              headers_for(user),
            )
            last_response.status.should == 200
            EM.next_tick { EM.stop }
          end
        end
      end
    end

    describe "DELETE /apps/:name" do
      let(:app_obj) { Models::App.make(:space => user.default_space) }

      before do
        3.times { Models::App.make }
        app_obj.guid.should_not be_nil
        @num_apps_before = Models::App.count
        delete "/apps/#{app_obj.name}", {}, headers_for(user)
      end

      it "should return success" do
        last_response.status.should == 200
      end

      it "should reduce the app count by 1" do
        Models::App.count.should == @num_apps_before - 1
      end
    end

    # FIXME: this still needs to switch from admin to user.  This can't happen
    # until services get correct permission settings
    describe "service binding" do
      describe "PUT /apps/:name adding and removing bindings" do
        before(:all) do
          @app_obj = Models::App.make(:space => admin.default_space)
          bound_instances = []
          5.times do
            instance = Models::ServiceInstance.make(:space => admin.default_space)
            bound_instances << instance
            Models::ServiceBinding.make(:app => @app_obj, :service_instance => instance)
          end

          @instance_to_bind = Models::ServiceInstance.make(:space => admin.default_space)
          @instance_to_unbind = bound_instances[2]

          service_instance_names = [@instance_to_bind.name]
          bound_instances.each do |i|
            service_instance_names << i.name unless i == @instance_to_unbind
          end

          @num_bindings_before = @app_obj.service_bindings.count

          req = Yajl::Encoder.encode(
            :services => service_instance_names,
            :credentials => { "foo" => "bar" }
          )

          put "/apps/#{@app_obj.name}", req, headers_for(admin)
          @app_obj.refresh
          @bound_instances = @app_obj.service_bindings.map { |b| b.service_instance }
        end

        it "should return success" do
          last_response.status.should == 200
        end

        it "should add the the specified binding to the app" do
          @bound_instances.should include(@instance_to_bind)
        end

        it "should remove the specified binding from the app" do
          @bound_instances.should_not include(@instance_to_unbind)
        end
      end
    end

    describe "PUT /apps/:name/application" do
      let(:app_obj) { Models::App.make(:space => user.default_space) }
      let(:tmpdir) { Dir.mktmpdir }

      after do
        FileUtils.rm_rf(tmpdir)
      end

      it "should return success" do
        zipname = File.join(tmpdir, "file.zip")
        create_zip(zipname, 10)
        zipfile = File.new(zipname)
        req = {
          :application => Rack::Test::UploadedFile.new(zipfile),
          :resources => Yajl::Encoder.encode([])
        }

        post "/apps/#{app_obj.name}/application", req, headers_for(user)
        last_response.status.should == 200
      end
    end
  end
end
